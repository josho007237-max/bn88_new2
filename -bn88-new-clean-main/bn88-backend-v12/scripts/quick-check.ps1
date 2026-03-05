param(
  [string]$BaseUrl = "http://localhost:3000",
  [string]$Email = "root@bn9.local",
  [string]$Password = "bn9@12345"
)

$ErrorActionPreference = 'Stop'

$loginUrl = "$BaseUrl/api/admin/auth/login"
$body = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress

Write-Host "[quick-check] POST $loginUrl"
try {
  $resp = Invoke-RestMethod -Uri $loginUrl -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 10
} catch {
  Write-Host "[quick-check][FAIL] login request failed: $loginUrl" -ForegroundColor Red
  throw
}

$token = $resp.token
if (-not $token) { $token = $resp.accessToken }
if (-not $token) {
  Write-Host "[quick-check][FAIL] token/accessToken missing" -ForegroundColor Red
  exit 1
}

Write-Host "[quick-check][PASS] token received" -ForegroundColor Green
exit 0
