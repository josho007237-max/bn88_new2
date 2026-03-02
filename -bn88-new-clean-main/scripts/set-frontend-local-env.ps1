$ErrorActionPreference = 'Stop'

function Info([string]$Message) {
  Write-Host "[set-frontend-local-env] $Message" -ForegroundColor Cyan
}

function Fail([string]$Message) {
  Write-Host "[set-frontend-local-env] ERROR: $Message" -ForegroundColor Red
  exit 1
}

$repoRoot = (Resolve-Path (Split-Path -Parent $PSScriptRoot)).Path
$frontendDir = Join-Path $repoRoot 'bn88-frontend-dashboard-v12'
$envExamplePath = Join-Path $frontendDir '.env.example'
$envPath = Join-Path $frontendDir '.env'

if (-not (Test-Path $frontendDir)) { Fail "missing frontend dir: $frontendDir" }
if (-not (Test-Path $envExamplePath)) { Fail "missing .env.example: $envExamplePath" }

Copy-Item -Path $envExamplePath -Destination $envPath -Force

$content = Get-Content -Path $envPath -Raw
$content = $content -replace '(?m)^VITE_API_BASE=.*$', 'VITE_API_BASE=http://127.0.0.1:3000'
$content = $content -replace '(?m)^VITE_ADMIN_API_BASE=.*$', 'VITE_ADMIN_API_BASE=http://127.0.0.1:3000'
$content = $content -replace '(?m)^VITE_API_BASE_URL=.*$', 'VITE_API_BASE_URL=http://127.0.0.1:3000'

Set-Content -Path $envPath -Value $content -Encoding UTF8
Info "updated frontend env: $envPath"
