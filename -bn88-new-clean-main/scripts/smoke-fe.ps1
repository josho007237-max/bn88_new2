param(
  [int]$FePort = 5555,
  [string]$BaseUrl = 'http://127.0.0.1:3000',
  [string]$Email = 'root@bn9.local',
  [string]$Password = 'bn9@12345',
  [string]$Tenant = 'bn9'
)

$ErrorActionPreference = 'Stop'

function Info([string]$Message) { Write-Host "[smoke-fe] $Message" -ForegroundColor Cyan }
function Warn([string]$Message) { Write-Host "[smoke-fe] WARN: $Message" -ForegroundColor Yellow }
function Fail([string]$Message) { Write-Host "[smoke-fe] ERROR: $Message" -ForegroundColor Red; exit 1 }

$frontendDir = Join-Path (Get-Location).Path 'bn88-frontend-dashboard-v12'
if (-not (Test-Path $frontendDir)) { Fail 'missing bn88-frontend-dashboard-v12 from current directory' }

$envFile = Join-Path $frontendDir '.env.local'
'VITE_API_BASE=/api' | Set-Content -Path $envFile -Encoding UTF8
Info "wrote $envFile"

Info "health via FE proxy => http://127.0.0.1:$FePort/api/health"
$health = Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:$FePort/api/health"
if ($null -eq $health) { Fail 'health response is null' }

$loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress
Info "login => $BaseUrl/api/admin/auth/login"
$login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/admin/auth/login" -ContentType 'application/json' -Body $loginBody
$token = $login.token
if ([string]::IsNullOrWhiteSpace($token)) { Fail 'login did not return token' }

$curlCmd = if (Get-Command curl.exe -ErrorAction SilentlyContinue) { 'curl.exe' } elseif (Get-Command curl -ErrorAction SilentlyContinue) { 'curl' } else { $null }
if (-not $curlCmd) {
  Warn 'curl not found; skipping SSE'
} else {
  $sseUrl = "$BaseUrl/api/live/$Tenant?token=$token"
  Info "SSE => $sseUrl"
  $sseOutput = & $curlCmd -i -N --max-time 5 $sseUrl 2>&1
  $sseText = ($sseOutput | Out-String)
  if ($sseText -match 'HTTP/\S+\s+200') {
    Write-Host '[smoke-fe] SSE connected (HTTP 200)' -ForegroundColor Green
  } else {
    Fail 'SSE did not connect (expected HTTP 200)'
  }
}

Write-Host '[smoke-fe] done' -ForegroundColor Green
