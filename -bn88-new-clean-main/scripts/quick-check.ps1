param(
  [string]$BaseUrl = 'http://127.0.0.1:3000',
  [string]$Email = 'root@bn9.local',
  [string]$Password = 'bn9@12345',
  [string]$Tenant = 'bn9'
)

$ErrorActionPreference = 'Stop'

function Pass([string]$m) { Write-Host "[PASS] $m" -ForegroundColor Green }
function Fail([string]$m) { Write-Host "[FAIL] $m" -ForegroundColor Red; $script:HasFail = $true }

$HasFail = $false

$ports = @(3000, 5555, 6380)
foreach ($port in $ports) {
  $listen = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
  if ($listen) { Pass "port $port is listening" } else { Fail "port $port is NOT listening" }
}

try {
  $health = Invoke-WebRequest -Uri "$BaseUrl/api/health" -Method Get -UseBasicParsing
  if ($health.StatusCode -eq 200) { Pass 'GET /api/health = 200' } else { Fail "GET /api/health = $($health.StatusCode)" }
} catch {
  Fail "GET /api/health error: $($_.Exception.Message)"
}

$token = $null
try {
  $loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json
  $loginRes = Invoke-RestMethod -Uri "$BaseUrl/api/admin/auth/login" -Method Post -ContentType 'application/json' -Body $loginBody
  $token = $loginRes.token
  if ($token) { Pass 'login success (token received)' } else { Fail 'login response has no token' }
} catch {
  Fail "login error: $($_.Exception.Message)"
}

if ($token) {
  try {
    $headers = @{ Authorization = "Bearer $token"; 'x-tenant' = $Tenant }
    $sessions = Invoke-WebRequest -Uri "$BaseUrl/api/admin/chat/sessions?limit=1" -Method Get -Headers $headers -UseBasicParsing
    if ($sessions.StatusCode -eq 200) { Pass 'GET /api/admin/chat/sessions = 200' } else { Fail "GET /api/admin/chat/sessions = $($sessions.StatusCode)" }
  } catch {
    Fail "GET /api/admin/chat/sessions error: $($_.Exception.Message)"
  }
}

if ($HasFail) {
  Write-Host '[SUMMARY] QUICK CHECK = FAIL' -ForegroundColor Red
  exit 1
}

Write-Host '[SUMMARY] QUICK CHECK = PASS' -ForegroundColor Green
