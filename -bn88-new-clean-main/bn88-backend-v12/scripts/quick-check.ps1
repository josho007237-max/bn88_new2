param(
  [string]$BaseUrl = "http://localhost:3000",
  [string]$Email = "root@bn9.local",
  [string]$Password = "bn9@12345"
)

$ErrorActionPreference = 'Stop'

$loginUrl = "$BaseUrl/api/admin/auth/login"
$bodyObj = @{ email = $Email; password = $Password }
$body = $bodyObj | ConvertTo-Json -Compress -Depth 4
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

Write-Host "[quick-check] POST $loginUrl"
try {
  $resp = Invoke-RestMethod -Uri $loginUrl -Method Post -ContentType 'application/json' -Body $bodyBytes -TimeoutSec 10
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
