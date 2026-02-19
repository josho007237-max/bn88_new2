param(
  [string]$BaseUrl = 'http://127.0.0.1:3000',
  [string]$Email = 'root@bn9.local',
  [string]$Password = 'bn9@12345',
  [string]$Tenant = 'bn9'
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  Write-Host "[smoke-all] ERROR: $Message" -ForegroundColor Red
  exit 1
}

Write-Host "[smoke-all] health => $BaseUrl/api/health"
$health = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/health"
if ($null -eq $health) { Fail 'health response is null' }
if ($health.ok -ne $true) { Fail "health.ok expected true, got '$($health.ok)'" }
if ($health.adminApi -ne $true) { Fail "health.adminApi expected true, got '$($health.adminApi)'" }

Write-Host "[smoke-all] login => $BaseUrl/api/admin/auth/login"
$loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress
$login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/admin/auth/login" -ContentType 'application/json' -Body $loginBody
$token = $login.token
if ([string]::IsNullOrWhiteSpace($token)) { Fail 'login did not return token' }

Write-Host "[smoke-all] bots => $BaseUrl/api/admin/bots"
$headers = @{ Authorization = "Bearer $token"; 'x-tenant' = $Tenant }
$bots = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/bots" -Headers $headers
if ($null -eq $bots) { Fail 'bots response is null' }
if ($null -eq $bots.items) { Fail 'bots.items missing in response' }
if ($bots.items.Count -le 0) { Fail "bots.items expected length > 0, got $($bots.items.Count)" }

Write-Host "[smoke-all] SSE => $BaseUrl/api/live/$Tenant?token=<token> (curl -i -N, max-time 5s)"
$curlCmd = if (Get-Command curl.exe -ErrorAction SilentlyContinue) { 'curl.exe' } elseif (Get-Command curl -ErrorAction SilentlyContinue) { 'curl' } else { $null }
if (-not $curlCmd) {
  Write-Host '[smoke-all] WARN: curl not found, skipping SSE check' -ForegroundColor Yellow
} else {
  $sseUrl = "$BaseUrl/api/live/$Tenant?token=$token"
  $sseOutput = & $curlCmd -i -N --max-time 5 $sseUrl 2>&1
  $sseText = ($sseOutput | Out-String)
  if ($sseText -match 'HTTP/\S+\s+401' -or $sseText -match 'HTTP/\S+\s+403') {
    Write-Host '[smoke-all] WARN: SSE auth pending' -ForegroundColor Yellow
  } elseif ($sseText -match 'HTTP/\S+\s+200') {
    Write-Host '[smoke-all] SSE probe returned HTTP 200' -ForegroundColor Green
  } else {
    Write-Host '[smoke-all] WARN: SSE probe did not return 200/401/403 (check manually)' -ForegroundColor Yellow
  }
}

Write-Host '[smoke-all] OK: health, login, and bots checks passed' -ForegroundColor Green
