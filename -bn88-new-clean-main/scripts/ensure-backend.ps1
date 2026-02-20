param(
  [string]$BaseUrl = "http://127.0.0.1:3000",
  [string]$Tenant = "bn9",
  [string]$Email = "root@bn9.local",
  [string]$Password = "bn9@12345",
  [int]$MaxRetries = 10
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
  Write-Host "[ensure-backend] ERROR: $Message" -ForegroundColor Red
  exit 1
}

function Is-PortListening([int]$Port) {
  try {
    $conn = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
    return $null -ne $conn
  } catch {
    return $false
  }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$backendDir = Join-Path $repoRoot "bn88-backend-v12"

if (-not (Is-PortListening -Port 3000)) {
  Write-Host "[ensure-backend] port 3000 not listening -> start backend" -ForegroundColor Yellow
  Start-Process -FilePath "powershell" -ArgumentList @(
    "-NoExit",
    "-Command",
    "cd '$backendDir'; npm run dev"
  ) | Out-Null
} else {
  Write-Host "[ensure-backend] port 3000 already listening" -ForegroundColor Green
}

$ready = $false
for ($retryIndex = 1; $retryIndex -le $MaxRetries; $retryIndex++) {
  try {
    $healthResp = Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/api/health" -TimeoutSec 4
    if ($healthResp.StatusCode -eq 200) {
      $ready = $true
      break
    }
  } catch {
    # retry
  }
  Start-Sleep -Seconds 2
}

if (-not $ready) {
  Fail "backend not ready after $MaxRetries retries ($BaseUrl/api/health)"
}

Write-Host "[ensure-backend] health ready" -ForegroundColor Green

$loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress
$loginResp = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/admin/auth/login" -ContentType "application/json" -Body $loginBody
$token = [string]$loginResp.token
if ([string]::IsNullOrWhiteSpace($token)) {
  Fail "login did not return token"
}

$curlCmd = if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
  "curl.exe"
} elseif (Get-Command curl -ErrorAction SilentlyContinue) {
  "curl"
} else {
  $null
}

if (-not $curlCmd) {
  Fail "curl/curl.exe not found"
}

$encodedToken = [uri]::EscapeDataString($token)
$sseUrl = "$BaseUrl/api/live/$Tenant?token=$encodedToken"
$sseHeaders = & $curlCmd -i -N --max-time 5 $sseUrl 2>&1 | Out-String

if ($sseHeaders -notmatch "HTTP/\S+\s+200") {
  Fail "SSE expected HTTP 200, got: $($sseHeaders -split "`n" | Select-Object -First 1)"
}
if ($sseHeaders -notmatch "(?i)content-type:\s*text/event-stream") {
  Fail "SSE missing Content-Type: text/event-stream"
}

Write-Host "[ensure-backend] SSE OK: text/event-stream" -ForegroundColor Green
