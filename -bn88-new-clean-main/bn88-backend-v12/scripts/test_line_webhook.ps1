#requires -Version 5.1

<#
  Reliable LINE webhook testing on Windows:
  - Computes X-Line-Signature from raw body.json bytes (no PowerShell JSON re-encoding)
  - Uses curl.exe (not Invoke-WebRequest) and always passes -g (disable URL globbing)

  Usage:
    $env:LINE_CHANNEL_SECRET="..."
    pwsh -File .\scripts\test_line_webhook.ps1
    pwsh -File .\scripts\test_line_webhook.ps1 -InvalidSignature   # expect 401

  Optional:
    $env:PORT=4100   # skip port probing
#>

param(
  [switch]$InvalidSignature,
  [string]$BodyPath = (Join-Path $PSScriptRoot "body.json"),
  [string]$Url
)

$ErrorActionPreference = "Stop"

function Test-HealthPort {
  param([Parameter(Mandatory = $true)][int]$Port)

  $healthUrl = "http://127.0.0.1:$Port/api/health"
  $code = & curl.exe -g --silent --show-error --connect-timeout 1 --max-time 3 --output NUL --write-out "%{http_code}" $healthUrl
  if ($LASTEXITCODE -ne 0) { return $false }
  return ($code.Trim() -match "^[23][0-9][0-9]$")
}

function Resolve-BackendPort {
  if ($env:PORT) {
    $p = [int]$env:PORT
    if (-not (Test-HealthPort -Port $p)) {
      throw "env:PORT is set to $p but /api/health did not respond. Unset `$env:PORT or start the backend on that port."
    }
    return $p
  }

  foreach ($p in @(3000, 4100)) {
    if (Test-HealthPort -Port $p) { return $p }
  }

  throw "Could not detect backend port. Set `$env:PORT or start the backend on 3000/4100."
}

function Get-LineSignature {
  param(
    [Parameter(Mandatory = $true)][byte[]]$BodyBytes,
    [Parameter(Mandatory = $true)][string]$Secret
  )

  $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($Secret)
  $hmac = [System.Security.Cryptography.HMACSHA256]::new($keyBytes)
  try {
    $hashBytes = $hmac.ComputeHash($BodyBytes)
  } finally {
    $hmac.Dispose()
  }
  return [System.Convert]::ToBase64String($hashBytes)
}

function Get-LastHeaderBlock {
  param([Parameter(Mandatory = $true)][string[]]$Lines)

  $blocks = New-Object System.Collections.Generic.List[object]
  $current = New-Object System.Collections.Generic.List[string]

  foreach ($line in $Lines) {
    if ($line -match "^\s*$") {
      if ($current.Count -gt 0) {
        $blocks.Add($current.ToArray())
        $current = New-Object System.Collections.Generic.List[string]
      }
      continue
    }
    $current.Add($line)
  }
  if ($current.Count -gt 0) { $blocks.Add($current.ToArray()) }

  for ($i = $blocks.Count - 1; $i -ge 0; $i--) {
    $b = $blocks[$i]
    if ($b.Count -gt 0 -and $b[0] -match "^HTTP\\/") { return $b }
  }

  return $Lines
}

if (-not $env:LINE_CHANNEL_SECRET) {
  throw "Missing env var LINE_CHANNEL_SECRET. Example: `$env:LINE_CHANNEL_SECRET = '...'"
}

$port = Resolve-BackendPort
if (-not $Url) { $Url = "http://127.0.0.1:$port/api/webhooks/line" }

Write-Host ("chosen port: {0}" -f $port)
Write-Host ("mode: {0}" -f ($(if ($InvalidSignature) { "INVALID signature (expect 401)" } else { "VALID signature" })))
Write-Host ("url: {0}" -f $Url)

if (-not (Test-Path -LiteralPath $BodyPath)) {
  $json = '{"destination":"U00000000000000000000000000000000","events":[]}'
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllBytes($BodyPath, $utf8NoBom.GetBytes($json))
  Write-Host ("created: {0}" -f (Resolve-Path -LiteralPath $BodyPath).Path)
}

$bodyAbs = (Resolve-Path -LiteralPath $BodyPath).Path
$rawBytes = [System.IO.File]::ReadAllBytes($bodyAbs)

$sig = Get-LineSignature -BodyBytes $rawBytes -Secret $env:LINE_CHANNEL_SECRET
if ($InvalidSignature) {
  $sig = $sig.Substring(0, $sig.Length - 1) + ($(if ($sig.EndsWith("A")) { "B" } else { "A" }))
}

$curlArgs = @(
  "-g",
  "--silent",
  "--show-error",
  "--output", "NUL",
  "--dump-header", "-",
  "--request", "POST",
  "--header", "Content-Type: application/json",
  "--header", "X-Line-Signature: $sig",
  "--data-binary", "@$bodyAbs",
  $Url
)

$headerLines = & curl.exe @curlArgs
if ($LASTEXITCODE -ne 0) { throw "curl.exe failed (exit=$LASTEXITCODE)" }

$block = Get-LastHeaderBlock -Lines $headerLines
if ($block.Count -gt 0) {
  Write-Host ""
  Write-Host ("status: {0}" -f $block[0])

  $keep = @(
    "date",
    "server",
    "content-type",
    "content-length",
    "x-powered-by",
    "etag"
  )

  $found = @{}
  for ($i = 1; $i -lt $block.Count; $i++) {
    $line = $block[$i]
    if ($line -match "^([^:]+):\\s*(.*)$") {
      $name = $matches[1].Trim()
      $value = $matches[2].Trim()
      $key = $name.ToLowerInvariant()
      if (-not $found.ContainsKey($key)) { $found[$key] = ("{0}: {1}" -f $name, $value) }
    }
  }

  foreach ($k in $keep) {
    if ($found.ContainsKey($k)) { Write-Host $found[$k] }
  }
}
