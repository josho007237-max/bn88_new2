param(
  [string]$Root = (Get-Location).Path,
  [string]$Email = "root@bn9.local",
  [string]$Password = "bn9@12345",
  [string]$Tenant = "bn9"
)

$ErrorActionPreference = 'Stop'
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force | Out-Null

function Write-Step([string]$msg) { Write-Host "[p0-smoke-admin] $msg" }

$rootResolved = (Resolve-Path $Root).Path
$findScript = Join-Path $rootResolved 'scripts/p0-find-backend.ps1'
if (-not (Test-Path $findScript)) {
  Write-Host "[FAIL] missing script: $findScript" -ForegroundColor Red
  exit 1
}

Write-Step "finding backend path via p0-find-backend.ps1"
$findOut = & $findScript -Root $rootResolved -Depth 5
$backend = $null
foreach ($line in $findOut) {
  if ($line -match '^\s*-\s+(.+bn88-backend-v12)\s*$') {
    $backend = $matches[1].Trim()
    break
  }
}
if (-not $backend) {
  Write-Host "[FAIL] backend not found" -ForegroundColor Red
  Write-Host $findOut
  exit 1
}

Write-Step "backend = $backend"
Set-Location -LiteralPath $backend

$portListening = $false
try {
  $conn = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction Stop | Select-Object -First 1
  if ($conn) { $portListening = $true }
} catch {
  try {
    $null = Invoke-WebRequest -Uri 'http://localhost:3000/api/health' -Method Get -TimeoutSec 3
    $portListening = $true
  } catch {
    $portListening = $false
  }
}

if (-not $portListening) {
  Write-Host "[FAIL] port 3000 is not listening" -ForegroundColor Red
  Write-Host "Hint: run 'npm run dev' in $backend"
  exit 1
}

Write-Step "port 3000 is listening"

if (-not (Get-Command rg -ErrorAction SilentlyContinue)) {
  Write-Host "[FAIL] rg not found in PATH" -ForegroundColor Red
  exit 1
}

$authFileHit = rg -n -S -F 'router.post("/login"' src/routes/admin/auth.ts 2>$null | Select-Object -First 1
if (-not $authFileHit) {
  $authFileHit = rg -n -S -F '/api/admin/auth' src 2>$null | Select-Object -First 1
}
$loginUrl = 'http://localhost:3000/api/admin/auth/login'
Write-Step "login endpoint = $loginUrl"
if ($authFileHit) { Write-Step "login route evidence: $authFileHit" }

$loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress
try {
  $loginResp = Invoke-RestMethod -Uri $loginUrl -Method Post -ContentType 'application/json' -Body $loginBody -TimeoutSec 10
} catch {
  Write-Host "[FAIL] login request failed at $loginUrl" -ForegroundColor Red
  Write-Host "Hint files: src/routes/admin/auth.ts , src/server.ts"
  throw
}

$token = $loginResp.token
if (-not $token) { $token = $loginResp.accessToken }
if (-not $token) {
  Write-Host "[FAIL] login ok but token/accessToken missing" -ForegroundColor Red
  Write-Host "Hint files: src/routes/admin/auth.ts"
  exit 1
}

$botsUrl = 'http://localhost:3000/api/admin/bots'
$headers = @{ Authorization = "Bearer $token"; 'x-tenant' = $Tenant }

$code = 0
try {
  $resp = Invoke-WebRequest -Uri $botsUrl -Method Get -Headers $headers -TimeoutSec 10
  $code = [int]$resp.StatusCode
} catch {
  if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
    $code = [int]$_.Exception.Response.StatusCode
  } else {
    Write-Host "[FAIL] request to /api/admin/bots failed (no status code)" -ForegroundColor Red
    Write-Host "Hint files: src/server.ts , src/mw/auth.ts , src/middleware/basicAuth.ts , src/routes/admin/bots.ts"
    throw
  }
}

switch ($code) {
  200 {
    Write-Host "[PASS] /api/admin/bots => 200" -ForegroundColor Green
    exit 0
  }
  401 {
    Write-Host "[FAIL] /api/admin/bots => 401" -ForegroundColor Red
    Write-Host "Hint files: src/mw/auth.ts , src/routes/admin/auth.ts"
    exit 1
  }
  403 {
    Write-Host "[FAIL] /api/admin/bots => 403" -ForegroundColor Red
    Write-Host "Hint files: src/middleware/basicAuth.ts , src/routes/admin/bots.ts"
    exit 1
  }
  default {
    Write-Host ("[FAIL] /api/admin/bots => {0}" -f $code) -ForegroundColor Red
    Write-Host "Hint files: src/server.ts , src/mw/auth.ts , src/middleware/basicAuth.ts , src/routes/admin/bots.ts"
    exit 1
  }
}
