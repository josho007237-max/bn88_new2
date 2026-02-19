param(
  [string]$BaseDomain = "api.bn9.app",
  [string]$Tenant = "bn9",
  [string]$Email = "root@bn9.local",
  [string]$Password = "bn9@12345",
  [int]$SseTimeoutSec = 5
)

$ErrorActionPreference = "Stop"
$script:FailCount = 0

function Write-CheckResult {
  param(
    [string]$Title,
    [bool]$Ok,
    [string]$Detail = ""
  )

  if ($Ok) {
    Write-Host "[PASS] $Title" -ForegroundColor Green
  } else {
    Write-Host "[FAIL] $Title" -ForegroundColor Red
    $script:FailCount++
  }

  if ($Detail) {
    Write-Host "       $Detail" -ForegroundColor DarkGray
  }
}

$baseUrl = "https://$BaseDomain"
$healthUrl = "$baseUrl/api/health"
$loginUrl = "$baseUrl/api/admin/auth/login"
$botsUrl = "$baseUrl/api/admin/bots"

Write-Host "=== SMOKE E2E DOMAIN (health -> login -> bots -> sse) ===" -ForegroundColor Cyan
Write-Host "BaseUrl: $baseUrl | Tenant: $Tenant" -ForegroundColor DarkCyan

# 1) Health must be 200
try {
  $healthCode = & curl.exe -sS -o NUL -w "%{http_code}" --max-time 10 --ssl-no-revoke "$healthUrl" 2>&1
  $ok = ($LASTEXITCODE -eq 0 -and "$healthCode" -eq "200")
  Write-CheckResult "Health $healthUrl" $ok "status=$healthCode"
} catch {
  Write-CheckResult "Health $healthUrl" $false $_.Exception.Message
}

# 2) Login and receive token
$token = $null
try {
  $jsonBody = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress
  $loginRaw = & curl.exe -sS --ssl-no-revoke --max-time 15 -H "Content-Type: application/json" -d "$jsonBody" "$loginUrl" 2>&1
  if ($LASTEXITCODE -ne 0) { throw "curl exit code $LASTEXITCODE" }

  $loginObj = $loginRaw | ConvertFrom-Json
  $token = if ($loginObj.token) { "$($loginObj.token)" } elseif ($loginObj.accessToken) { "$($loginObj.accessToken)" } else { $null }
  $ok = -not [string]::IsNullOrWhiteSpace($token)
  Write-CheckResult "Login POST /api/admin/auth/login" $ok (if ($ok) { "tokenLen=$($token.Length)" } else { "token missing" })
} catch {
  Write-CheckResult "Login POST /api/admin/auth/login" $false $_.Exception.Message
}

# 3) Bots must be 200
try {
  if ([string]::IsNullOrWhiteSpace($token)) { throw "token is empty" }
  $botsCode = & curl.exe -sS -o NUL -w "%{http_code}" --ssl-no-revoke --max-time 15 -H "Authorization: Bearer $token" -H "x-tenant: $Tenant" "$botsUrl" 2>&1
  $ok = ($LASTEXITCODE -eq 0 -and "$botsCode" -eq "200")
  Write-CheckResult "GET /api/admin/bots" $ok "status=$botsCode"
} catch {
  Write-CheckResult "GET /api/admin/bots" $false $_.Exception.Message
}

# 4) SSE must be 200 and include ping in timeout
try {
  if ([string]::IsNullOrWhiteSpace($token)) { throw "token is empty" }
  $encToken = [uri]::EscapeDataString($token)
  $sseUrl = "$baseUrl/api/live/$Tenant?token=$encToken"
  $sseOut = & curl.exe -sS -i -N --ssl-no-revoke --max-time "$SseTimeoutSec" "$sseUrl" 2>&1 | Out-String
  $httpOk = ($sseOut -match "HTTP/\S+\s+200")
  $hasPing = ($sseOut -match "ping")
  $ok = ($httpOk -and $hasPing)
  $detail = "http200=$httpOk ping=$hasPing timeout=${SseTimeoutSec}s"
  Write-CheckResult "SSE /api/live/$Tenant?token=..." $ok $detail
} catch {
  Write-CheckResult "SSE /api/live/$Tenant?token=..." $false $_.Exception.Message
}

Write-Host ""
if ($script:FailCount -eq 0) {
  Write-Host "SMOKE E2E DOMAIN RESULT: PASS ✅" -ForegroundColor Green
  exit 0
}

Write-Host "SMOKE E2E DOMAIN RESULT: FAIL ❌ ($script:FailCount checks failed)" -ForegroundColor Red
exit 1
