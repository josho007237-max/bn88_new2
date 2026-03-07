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

$ports = @(3000, 5555, 6380)
foreach ($port in $ports) {
  $listen = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
  if ($listen) {
    Pass "port $port is listening"
    continue
  }

  if ($port -eq 3000) {
    Fail 'PORT' "port 3000 is NOT listening (backend)" "Run: cd .\bn88-backend-v12; npm run dev"
    continue
  }
  if ($port -eq 5555) {
    Fail 'PORT' "port 5555 is NOT listening (frontend)" "Run: cd .\bn88-frontend-dashboard-v12; npm run dev -- --port 5555"
    continue
  }

  Fail 'PORT' "port 6380 is NOT listening (redis)" "Run: docker start bn88-redis  (or)  docker run -d --name bn88-redis -p 6380:6379 redis:8-alpine"
}

try {
  $health = Invoke-WebRequest -Uri "$BaseUrl/api/health" -Method Get -UseBasicParsing
  if ($health.StatusCode -eq 200) {
    Pass 'GET /api/health = 200'
    try {
      $healthJson = $health.Content | ConvertFrom-Json
      Write-Host ("[INFO] /api/health adminApi = {0}" -f $healthJson.adminApi) -ForegroundColor Cyan
    } catch {
      Write-Host "[INFO] /api/health adminApi = (unparseable response)" -ForegroundColor Yellow
    }
  } else {
    Fail 'HEALTH' "GET /api/health = $($health.StatusCode)" "Check backend logs and retry: curl http://127.0.0.1:3000/api/health"
  }
} catch {
  Fail 'HEALTH' "GET /api/health error: $($_.Exception.Message)" "Ensure backend is running on :3000 and retry"
}

$token = $null
try {
  $loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json
  $loginHeaders = @{ 'x-tenant' = $Tenant }
  $loginRes = Invoke-RestMethod -Uri "$BaseUrl/api/admin/auth/login" -Method Post -ContentType 'application/json' -Headers $loginHeaders -Body $loginBody
  $token = $loginRes.token
  if ($loginRes.ok -eq $false -and $loginRes.message -eq 'not_found') {
    Fail 'LOGIN' 'login returned {ok:false,message:not_found}' "missing x-tenant header (set -Headers @{ 'x-tenant' = '$Tenant' })"
  } elseif ($token) {
    Pass 'login success (token received)'
  } else {
    Fail 'LOGIN' 'login response has no token' "Use valid email/password and x-tenant header: $Tenant"
  }
} catch {
  $resp = $_.ErrorDetails.Message
  if ($resp -and $resp -match '"ok"\s*:\s*false' -and $resp -match '"message"\s*:\s*"not_found"') {
    Fail 'LOGIN' 'login returned {ok:false,message:not_found}' "missing x-tenant header (set -Headers @{ 'x-tenant' = '$Tenant' })"
  } else {
    Fail 'LOGIN' "login error: $($_.Exception.Message)" "Retry: Invoke-RestMethod -Method Post -Uri '$BaseUrl/api/admin/auth/login' -ContentType 'application/json' -Headers @{ 'x-tenant' = '$Tenant' } -Body (@{email='$Email';password='$Password'} | ConvertTo-Json)"
  }
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
