param(
  [string]$BaseUrl = "http://127.0.0.1:3000",
  [string]$Tenant = "bn9",
  [string]$Email = "root@bn9.local",
  [string]$Password = "bn9@12345",
  [int]$SseTimeoutSec = 8
)

$ErrorActionPreference = "Stop"

function Invoke-CurlJson {
  param(
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)][string]$Url,
    [hashtable]$Headers,
    [string]$Body,
    [int]$MaxTimeSec = 20
  )

  $args = @("-sS", "--max-time", "$MaxTimeSec", "-X", $Method)
  if ($Headers) {
    foreach ($k in $Headers.Keys) {
      $args += @("-H", "$k: $($Headers[$k])")
    }
  }
  if ($null -ne $Body -and $Body.Length -gt 0) {
    $args += @("-d", $Body)
  }
  $args += $Url

  $raw = & curl.exe @args 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "curl failed ($LASTEXITCODE): $raw"
  }

  return $raw
}

function Find-RoutePath {
  param(
    [string]$Content,
    [string]$Pattern,
    [string]$Name
  )

  $m = [regex]::Match($Content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if (-not $m.Success) {
    throw "cannot parse $Name path from src/routes/admin/chat.ts"
  }
  return $m.Groups["path"].Value
}

Write-Host "=== SSE E2E (single run) ===" -ForegroundColor Cyan
Write-Host "BaseUrl: $BaseUrl | Tenant: $Tenant"

# 1) Login
$loginUrl = "$BaseUrl/api/admin/auth/login"
$loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress
$loginRaw = Invoke-CurlJson -Method "POST" -Url $loginUrl -Headers @{ "Content-Type" = "application/json" } -Body $loginBody
$loginObj = $loginRaw | ConvertFrom-Json
$token = if ($loginObj.token) { "$($loginObj.token)" } elseif ($loginObj.accessToken) { "$($loginObj.accessToken)" } else { $null }
if ([string]::IsNullOrWhiteSpace($token)) {
  throw "login succeeded but token/accessToken not found: $loginRaw"
}
Write-Host "[1/6] login ok -> tokenLen=$($token.Length)"

# 2-3) Parse routes from chat.ts
$chatRoutePath = Join-Path $PSScriptRoot "../routes/admin/chat.ts"
if (-not (Test-Path $chatRoutePath)) {
  throw "chat route file not found: $chatRoutePath"
}
$chatContent = Get-Content -Raw -Path $chatRoutePath

$listPath = Find-RoutePath -Content $chatContent -Name "list sessions (router.get)" -Pattern 'router\.get\(\s*"(?<path>[^"]+)"[\s\S]*?const sessions = await prisma\.chatSession\.findMany'
$patchMetaPath = Find-RoutePath -Content $chatContent -Name "meta patch (router.patch)" -Pattern 'router\.patch\(\s*"(?<path>[^"]+)"[\s\S]*?chat:session:meta_updated'

Write-Host "[2/6] parsed list path  : $listPath"
Write-Host "[3/6] parsed patch path : $patchMetaPath"

# 2) SSE command (plus auto-check)
$encToken = [uri]::EscapeDataString($token)
$sseUrl = "$BaseUrl/api/live/$Tenant?token=$encToken"
$sseCmd = "curl -N -i `"$sseUrl`""
Write-Host "[SSE] Open another terminal and run:" -ForegroundColor Yellow
Write-Host "      $sseCmd" -ForegroundColor DarkYellow

$ssePreview = & curl.exe -sS -i -N --max-time "$SseTimeoutSec" "$sseUrl" 2>&1 | Out-String
$http200 = ($ssePreview -match "HTTP/\S+\s+200")
Write-Host "[SSE] preview within ${SseTimeoutSec}s -> http200=$http200"

# 4) list sessions -> sessionId
$listUrl = "$BaseUrl/api/admin/chat$listPath?limit=1"
$listRaw = Invoke-CurlJson -Method "GET" -Url $listUrl -Headers @{ "Authorization" = "Bearer $token"; "x-tenant" = $Tenant } -Body ""
$listObj = $listRaw | ConvertFrom-Json
$sessionId = $listObj.items[0].id
if ([string]::IsNullOrWhiteSpace($sessionId)) {
  throw "sessionId not found from list response: $listRaw"
}
Write-Host "[4/6] list sessions ok -> sessionId=$sessionId"

# 5) patch meta -> trigger broadcast
$patchPathResolved = $patchMetaPath -replace ":id", $sessionId
$patchUrl = "$BaseUrl/api/admin/chat$patchPathResolved"
$metaBody = @{ hasProblem = $true } | ConvertTo-Json -Compress
$patchRaw = Invoke-CurlJson -Method "PATCH" -Url $patchUrl -Headers @{ "Authorization" = "Bearer $token"; "x-tenant" = $Tenant; "Content-Type" = "application/json" } -Body $metaBody

# 6) print result
Write-Host ""
Write-Host "=== RESULT ===" -ForegroundColor Green
Write-Host "loginUrl   : $loginUrl"
Write-Host "sseUrl     : $sseUrl"
Write-Host "listUrl    : $listUrl"
Write-Host "patchUrl   : $patchUrl"
Write-Host ""
Write-Host "list response:"
Write-Host $listRaw
Write-Host ""
Write-Host "patch response:"
Write-Host $patchRaw
Write-Host ""
Write-Host "Expected SSE event: type=chat:session:meta_updated sessionId=$sessionId"
