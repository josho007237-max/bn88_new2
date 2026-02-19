param(
  [string]$BaseUrl = 'http://127.0.0.1:3000',
  [string]$Email = 'root@bn9.local',
  [string]$Password = 'bn9@12345',
  [string]$Tenant = 'bn9'
)

$ErrorActionPreference = 'Stop'

function Info([string]$Message) {
  Write-Host "[smoke-local] $Message" -ForegroundColor Cyan
}

function Warn([string]$Message) {
  Write-Host "[smoke-local] WARN: $Message" -ForegroundColor Yellow
}

function Fail([string]$Message) {
  Write-Host "[smoke-local] ERROR: $Message" -ForegroundColor Red
  exit 1
}

Info "health => $BaseUrl/api/health"
$health = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/health"
if ($null -eq $health) { Fail 'health response is null' }

Info "login => $BaseUrl/api/admin/auth/login"
$loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress
$login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/admin/auth/login" -ContentType 'application/json' -Body $loginBody
$token = $login.token
if ([string]::IsNullOrWhiteSpace($token)) { Fail 'login did not return token' }

Info "bots => $BaseUrl/api/admin/bots"
$headers = @{ Authorization = "Bearer $token"; 'x-tenant' = $Tenant }
$bots = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/bots" -Headers $headers
if ($null -eq $bots) { Fail 'bots response is null' }
if ($bots.ok -ne $true) { Fail "bots.ok expected true, got '$($bots.ok)'" }

$curlCmd = if (Get-Command curl.exe -ErrorAction SilentlyContinue) { 'curl.exe' } elseif (Get-Command curl -ErrorAction SilentlyContinue) { 'curl' } else { $null }
if (-not $curlCmd) {
  Warn 'curl not found, cannot test SSE'
} else {
  $sseUrl = "$BaseUrl/api/live/$Tenant?token=$token"
  Info "sse => $sseUrl"
  $sseOutput = & $curlCmd -i -N --max-time 5 $sseUrl 2>&1
  $sseText = ($sseOutput | Out-String)
  if ($sseText -match 'HTTP/\S+\s+200') {
    Write-Host '[smoke-local] SSE connected (HTTP 200)' -ForegroundColor Green
  } else {
    Fail 'SSE did not connect (expected HTTP 200)'
  }
}

$envFile = 'bn88-frontend-dashboard-v12/.env.local'
if (-not (Test-Path $envFile)) {
  Warn 'frontend .env.local missing'
} else {
  $envContent = Get-Content -Path $envFile -Raw
  if ($envContent -match 'VITE_API_BASE=/api') {
    Write-Host '[smoke-local] frontend env VITE_API_BASE=/api OK' -ForegroundColor Green
  } else {
    Warn 'frontend .env.local does not contain VITE_API_BASE=/api'
  }
}

Write-Host '[smoke-local] local smoke completed' -ForegroundColor Green
