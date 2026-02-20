param(
  [string]$BaseUrl = 'http://127.0.0.1:3000',
  [string]$Email = 'root@bn9.local',
  [string]$Password = 'bn9@12345',
  [string]$Tenant = 'bn9'
)

$ErrorActionPreference = 'Stop'

function Write-Section([string]$Message) {
  Write-Host "[smoke-all] $Message" -ForegroundColor Cyan
}

function Warn([string]$Message) {
  Write-Host "[smoke-all] WARN: $Message" -ForegroundColor Yellow
}

function Fail([string]$Message) {
  Write-Host "[smoke-all] ERROR: $Message" -ForegroundColor Red
  exit 1
}

$repoRoot = (& git rev-parse --show-toplevel 2>$null).Trim()
if (-not $repoRoot) {
  Fail 'cannot detect repository root via git rev-parse --show-toplevel'
}

Write-Section "repo root => $repoRoot"
$backendDir = Join-Path $repoRoot 'bn88-backend-v12'
$frontendDir = Join-Path $repoRoot 'bn88-frontend-dashboard-v12'
if (-not (Test-Path $backendDir)) { Fail 'missing bn88-backend-v12 at repo root' }
if (-not (Test-Path $frontendDir)) { Fail 'missing bn88-frontend-dashboard-v12 at repo root' }

$ports = @(3000, 5555, 6380)
foreach ($port in $ports) {
  $connections = @(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)
  if ($connections.Count -gt 0) {
    $pids = ($connections | Select-Object -ExpandProperty OwningProcess -Unique) -join ','
    Write-Host "[smoke-all] port $port listening (PID: $pids)" -ForegroundColor Green
  } else {
    Warn "port $port is not listening"
  }
}

Write-Section "GET $BaseUrl/api/health"
$health = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/health"
if ($null -eq $health) { Fail 'health response is null' }

Write-Section "POST $BaseUrl/api/admin/auth/login"
$loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress
$login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/admin/auth/login" -ContentType 'application/json' -Body $loginBody
$token = $login.token
if ([string]::IsNullOrWhiteSpace($token)) { Fail 'login did not return token' }

Write-Section "GET $BaseUrl/api/admin/bots (x-tenant=$Tenant)"
$headers = @{ Authorization = "Bearer $token"; 'x-tenant' = $Tenant }
$bots = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/bots" -Headers $headers
if ($null -eq $bots) { Fail 'bots response is null' }

$apiFile = Join-Path $frontendDir 'src/lib/api.ts'
if (-not (Test-Path $apiFile)) { Fail 'missing bn88-frontend-dashboard-v12/src/lib/api.ts' }
$dupCount = @(Select-String -Path $apiFile -Pattern '^\s*function\s+getLineContentPath\s*\(').Count
if ($dupCount -ne 1) {
  Fail "expected exactly 1 getLineContentPath function, found $dupCount"
}
Write-Host '[smoke-all] getLineContentPath occurrences = 1' -ForegroundColor Green

$curlCmd = if (Get-Command curl.exe -ErrorAction SilentlyContinue) { 'curl.exe' } elseif (Get-Command curl -ErrorAction SilentlyContinue) { 'curl' } else { $null }
if (-not $curlCmd) {
  Warn 'curl not found, skipping domain health check'
} else {
  $domainUrl = 'https://api.bn9.app/api/health'
  Write-Section "domain check => $domainUrl"
  $httpCode = (& $curlCmd -sS -o NUL -w '%{http_code}' $domainUrl 2>$null).Trim()
  if (-not $httpCode) {
    Warn 'domain health check returned empty http_code'
  } elseif ($httpCode -eq '1033') {
    Warn 'domain returned 1033 (Cloudflare tunnel/ingress not pointing to :3000)'
  } else {
    Write-Host "[smoke-all] domain http_code=$httpCode" -ForegroundColor Green
  }
}

Write-Host '[smoke-all] completed' -ForegroundColor Green
