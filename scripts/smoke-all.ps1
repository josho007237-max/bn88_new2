[CmdletBinding()]
param(
  [switch]$InstallDeps,
  [switch]$StartBackend,
  [switch]$StartFrontend,
  [string]$BackendPort = "5555",
  [string]$FrontendPort = "3000",
  [string]$RedisPort = "6380",
  [string]$BackendBaseUrl = "http://127.0.0.1:5555",
  [string]$AuthToken = "",
  [string]$Tenant = "default",
  [string]$SsePath = "/api/admin/bots/stream"
)

$ErrorActionPreference = 'Stop'
$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
  param(
    [string]$Name,
    [bool]$Passed,
    [string]$Detail
  )

  $checks.Add([PSCustomObject]@{
      Name   = $Name
      Passed = $Passed
      Detail = $Detail
    })

  if ($Passed) {
    Write-Host "[PASS] $Name - $Detail" -ForegroundColor Green
  }
  else {
    Write-Host "[FAIL] $Name - $Detail" -ForegroundColor Red
  }
}

function Resolve-RepoRoot {
  $candidates = @()
  if ($PSScriptRoot) { $candidates += (Resolve-Path $PSScriptRoot).Path }
  $candidates += (Get-Location).Path

  foreach ($start in $candidates) {
    $current = $start
    while ($true) {
      $backendPkg = Join-Path $current "bn88-backend-v12/package.json"
      if (Test-Path $backendPkg) {
        return $current
      }

      $parent = Split-Path -Parent $current
      if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) {
        break
      }
      $current = $parent
    }
  }

  foreach ($start in $candidates) {
    $found = Get-ChildItem -Path $start -Filter package.json -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -match '[\\/]bn88-backend-v12[\\/]package\.json$' } |
      Select-Object -First 1

    if ($found) {
      return Split-Path -Parent (Split-Path -Parent $found.FullName)
    }
  }

  throw "Cannot detect repo root (expected bn88-backend-v12/package.json)."
}

function Run-NpmCiIfRequested {
  param([string]$Path)

  if (-not $InstallDeps) {
    return
  }

  Write-Host "Running npm ci in $Path" -ForegroundColor Cyan
  Push-Location $Path
  try {
    npm ci
  }
  finally {
    Pop-Location
  }
}

function Start-ServiceIfRequested {
  param(
    [string]$Name,
    [string]$Path,
    [switch]$ShouldStart
  )

  if (-not $ShouldStart) {
    return $null
  }

  Write-Host "Starting $Name from $Path" -ForegroundColor Cyan
  $proc = Start-Process -FilePath "npm" -ArgumentList "run","dev" -WorkingDirectory $Path -PassThru
  Start-Sleep -Seconds 4
  return $proc
}

function Test-PortListening {
  param([int]$Port)

  try {
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop | Select-Object -First 1
    return $null -ne $conn
  }
  catch {
    return $false
  }
}

function Invoke-JsonRequest {
  param(
    [string]$Method,
    [string]$Uri,
    [hashtable]$Headers,
    [string]$Body
  )

  $params = @{
    Method          = $Method
    Uri             = $Uri
    Headers         = $Headers
    ContentType     = 'application/json'
    TimeoutSec      = 15
    ErrorAction     = 'Stop'
    UseBasicParsing = $true
  }

  if ($Body) {
    $params.Body = $Body
  }

  return Invoke-WebRequest @params
}

$backendProc = $null
$frontendProc = $null

try {
  $repoRoot = Resolve-RepoRoot
  Write-Host "Repo root: $repoRoot" -ForegroundColor Yellow

  $backendDir = Join-Path $repoRoot 'bn88-backend-v12'
  $frontendDir = Join-Path $repoRoot 'bn88-frontend-dashboard-v12'

  $backendPkg = Join-Path $backendDir 'package.json'
  $frontendPkg = Join-Path $frontendDir 'package.json'

  Add-Check -Name 'Backend package.json exists' -Passed (Test-Path $backendPkg) -Detail $backendPkg
  Add-Check -Name 'Frontend package.json exists' -Passed (Test-Path $frontendPkg) -Detail $frontendPkg

  Run-NpmCiIfRequested -Path $backendDir
  Run-NpmCiIfRequested -Path $frontendDir

  $backendProc = Start-ServiceIfRequested -Name 'backend' -Path $backendDir -ShouldStart:$StartBackend
  $frontendProc = Start-ServiceIfRequested -Name 'frontend' -Path $frontendDir -ShouldStart:$StartFrontend

  Add-Check -Name 'Port 3000 listening' -Passed (Test-PortListening -Port ([int]$FrontendPort)) -Detail "localhost:$FrontendPort"
  Add-Check -Name 'Port 5555 listening' -Passed (Test-PortListening -Port ([int]$BackendPort)) -Detail "localhost:$BackendPort"
  Add-Check -Name 'Port 6380 listening' -Passed (Test-PortListening -Port ([int]$RedisPort)) -Detail "localhost:$RedisPort"

  $authHeader = if ([string]::IsNullOrWhiteSpace($AuthToken)) { '' } else { "Bearer $AuthToken" }
  $headers = @{
    'x-tenant' = $Tenant
  }
  if ($authHeader) {
    $headers['Authorization'] = $authHeader
  }

  try {
    $health = Invoke-JsonRequest -Method 'GET' -Uri "$BackendBaseUrl/api/health" -Headers $headers
    Add-Check -Name '/api/health' -Passed ($health.StatusCode -ge 200 -and $health.StatusCode -lt 500) -Detail "HTTP $($health.StatusCode)"
  }
  catch {
    Add-Check -Name '/api/health' -Passed $false -Detail $_.Exception.Message
  }

  try {
    $loginBody = '{"username":"smoke-test","password":"smoke-test"}'
    $login = Invoke-JsonRequest -Method 'POST' -Uri "$BackendBaseUrl/api/admin/auth/login" -Headers $headers -Body $loginBody
    Add-Check -Name '/api/admin/auth/login' -Passed ($login.StatusCode -ge 200 -and $login.StatusCode -lt 500) -Detail "HTTP $($login.StatusCode)"
  }
  catch {
    Add-Check -Name '/api/admin/auth/login' -Passed $false -Detail $_.Exception.Message
  }

  try {
    $bots = Invoke-JsonRequest -Method 'GET' -Uri "$BackendBaseUrl/api/admin/bots" -Headers $headers
    Add-Check -Name '/api/admin/bots (Authorization + x-tenant)' -Passed ($bots.StatusCode -ge 200 -and $bots.StatusCode -lt 500) -Detail "HTTP $($bots.StatusCode)"
  }
  catch {
    Add-Check -Name '/api/admin/bots (Authorization + x-tenant)' -Passed $false -Detail $_.Exception.Message
  }

  try {
    $curlHeaders = & curl.exe -sS -D - -o NUL -H "Accept: text/event-stream" -H "x-tenant: $Tenant" -H "Authorization: $authHeader" "$BackendBaseUrl$SsePath"
    $hasSse = $curlHeaders -match '(?im)^content-type:\s*text/event-stream'
    Add-Check -Name "SSE header ($SsePath)" -Passed $hasSse -Detail (($curlHeaders | Select-Object -First 8) -join "`n")
  }
  catch {
    Add-Check -Name "SSE header ($SsePath)" -Passed $false -Detail $_.Exception.Message
  }

  $cloudflaredPath = Join-Path $env:USERPROFILE '.cloudflared/config-bn88.yml'
  Add-Check -Name 'cloudflared config exists' -Passed (Test-Path $cloudflaredPath) -Detail $cloudflaredPath

  $failed = @($checks | Where-Object { -not $_.Passed }).Count
  Write-Host "`n======== SUMMARY ========" -ForegroundColor Yellow
  $checks | Format-Table -AutoSize

  if ($failed -gt 0) {
    Write-Host "Smoke check finished with $failed failure(s)." -ForegroundColor Red
    exit 1
  }

  Write-Host 'Smoke check finished: ALL PASS' -ForegroundColor Green
  exit 0
}
finally {
  if ($backendProc -and -not $backendProc.HasExited) {
    Write-Host "Stopping backend pid=$($backendProc.Id)" -ForegroundColor DarkYellow
    Stop-Process -Id $backendProc.Id -Force -ErrorAction SilentlyContinue
  }

  if ($frontendProc -and -not $frontendProc.HasExited) {
    Write-Host "Stopping frontend pid=$($frontendProc.Id)" -ForegroundColor DarkYellow
    Stop-Process -Id $frontendProc.Id -Force -ErrorAction SilentlyContinue
  }
}
