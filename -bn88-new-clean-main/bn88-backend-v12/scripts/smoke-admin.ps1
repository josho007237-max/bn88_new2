param(
  [string]$BaseUrl = 'http://127.0.0.1:3000',
  [string]$Email = 'root@bn9.local',
  [string]$Password = 'bn9@12345',
  [string]$Tenant = 'bn9'
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  Write-Host "[smoke-admin] ERROR: $Message" -ForegroundColor Red
  exit 1
}

Write-Host "[smoke-admin] health => $BaseUrl/api/health"
$health = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/health"
if ($null -eq $health) { Fail 'health response is null' }
if ($health.ok -ne $true) { Fail "health.ok expected true, got '$($health.ok)'" }
if ($health.adminApi -ne $true) { Fail "health.adminApi expected true, got '$($health.adminApi)'" }

Write-Host "[smoke-admin] login => $BaseUrl/api/admin/auth/login"
$loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress
$login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/admin/auth/login" -ContentType 'application/json' -Body $loginBody
$token = $login.token
if ([string]::IsNullOrWhiteSpace($token)) { Fail 'login did not return token' }

Write-Host "[smoke-admin] bots => $BaseUrl/api/admin/bots"
$headers = @{ Authorization = "Bearer $token"; 'x-tenant' = $Tenant }
$bots = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/bots" -Headers $headers
if ($null -eq $bots) { Fail 'bots response is null' }
if ($null -eq $bots.items) { Fail 'bots.items missing in response' }
if ($bots.items.Count -le 0) { Fail "bots.items expected length > 0, got $($bots.items.Count)" }

Write-Host "[smoke-admin] OK: health, login, and bots checks passed" -ForegroundColor Green
