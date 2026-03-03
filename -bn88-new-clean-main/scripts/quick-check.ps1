param(
  [string]$BaseUrl = 'http://127.0.0.1:3000',
  [string]$Email = 'root@bn9.local',
  [string]$Password = 'bn9@12345',
  [string]$Tenant = 'bn9'
)

$ErrorActionPreference = 'Stop'

function Pass([string]$m) { Write-Host "[PASS] $m" -ForegroundColor Green }
function Fail([string]$step, [string]$m, [string]$fix) { Write-Host "[FAIL][$step] $m" -ForegroundColor Red; if ($fix) { Write-Host "        Fix: $fix" -ForegroundColor Yellow }; $script:HasFail = $true; $script:FailSteps += $step }

$HasFail = $false
$FailSteps = @()

$dockerReady = $false
try {
  docker version | Out-Null
  if ($LASTEXITCODE -eq 0) { $dockerReady = $true }
} catch {
  $dockerReady = $false
}

$ports = @(3000, 5555, 6380)
foreach ($port in $ports) {
  $listen = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
  if ($listen) {
    Pass "port $port is listening"
    continue
  }

  if ($port -eq 6380 -and -not $dockerReady) {
    Write-Host "[SKIP][REDIS] Docker Desktop ยังไม่รัน: ข้าม Redis check ที่พอร์ต 6380" -ForegroundColor Yellow
    Write-Host "        Fix: เปิด Docker Desktop แล้วรัน .\scripts\quick-check.ps1 ใหม่" -ForegroundColor Yellow
    continue
  }

  Fail 'PORT' "port $port is NOT listening" "Run .\start-dev.ps1 (or check netstat -ano | findstr :$port)"
}

$listen3000 = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $listen3000) {
  Fail 'BACKEND' 'Backend not running' 'Open terminal and run: cd bn88-backend-v12; npm run dev (check startup logs)'
  $failed = ($FailSteps | Select-Object -Unique) -join ', '
  Write-Host "[SUMMARY] QUICK CHECK = FAIL (steps: $failed)" -ForegroundColor Red
  exit 1
}

try {
  $health = Invoke-WebRequest -Uri "$BaseUrl/api/health" -Method Get -UseBasicParsing
  if ($health.StatusCode -eq 200) { Pass 'GET /api/health = 200' } else { Fail 'HEALTH' "GET /api/health = $($health.StatusCode)" "Check backend logs and retry: curl http://127.0.0.1:3000/api/health" }
} catch {
  Fail 'HEALTH' "GET /api/health error: $($_.Exception.Message)" "Ensure backend is running on :3000 and retry"
}

$token = $null
try {
  $loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json
  $loginRes = Invoke-RestMethod -Uri "$BaseUrl/api/admin/auth/login" -Method Post -ContentType 'application/json' -Body $loginBody
  $token = $loginRes.token
  if ($token) { Pass 'login success (token received)' } else { Fail 'LOGIN' 'login response has no token' "Use valid email/password; sessions call also requires x-tenant: $Tenant" }
} catch {
  Fail 'LOGIN' "login error: $($_.Exception.Message)" "Retry: Invoke-RestMethod -Method Post -Uri '$BaseUrl/api/admin/auth/login' -ContentType 'application/json' -Body (@{email='$Email';password='$Password'} | ConvertTo-Json)"
}

if ($token) {
  try {
    $headers = @{ Authorization = "Bearer $token"; 'x-tenant' = $Tenant }
    $sessions = Invoke-WebRequest -Uri "$BaseUrl/api/admin/chat/sessions?limit=1" -Method Get -Headers $headers -UseBasicParsing
    if ($sessions.StatusCode -eq 200) { Pass 'GET /api/admin/chat/sessions = 200' } else { Fail 'SESSIONS' "GET /api/admin/chat/sessions = $($sessions.StatusCode)" "Verify headers Authorization Bearer token and x-tenant: $Tenant" }
  } catch {
    Fail 'SESSIONS' "GET /api/admin/chat/sessions error: $($_.Exception.Message)" "Retry with headers: @{ Authorization='Bearer <token>'; 'x-tenant'='$Tenant' }"
  }
}

if ($HasFail) {
  $failed = ($FailSteps | Select-Object -Unique) -join ', '
  Write-Host "[SUMMARY] QUICK CHECK = FAIL (steps: $failed)" -ForegroundColor Red
  Write-Host "[SUMMARY] Try fix: .\stop-dev.ps1; .\start-dev.ps1; .\scripts\quick-check.ps1" -ForegroundColor Yellow
  exit 1
}

Write-Host '[SUMMARY] QUICK CHECK = PASS' -ForegroundColor Green
