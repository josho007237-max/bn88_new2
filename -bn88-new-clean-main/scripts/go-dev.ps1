$ErrorActionPreference = 'Stop'

function Info([string]$Message) {
  Write-Host "[go-dev] $Message" -ForegroundColor Cyan
}

function Fail([string]$Message) {
  Write-Host "[go-dev] ERROR: $Message" -ForegroundColor Red
  exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$candidates = @(
  (Get-Location).Path,
  $scriptDir,
  (Split-Path -Parent $scriptDir),
  'C:\BN88-new-clean',
  'D:\BN88-new-clean',
  'E:\BN88-new-clean'
)

$root = $null
foreach ($candidate in $candidates) {
  if (-not $candidate) { continue }
  $backendPkg = Join-Path $candidate 'bn88-backend-v12\package.json'
  $frontendPkg = Join-Path $candidate 'bn88-frontend-dashboard-v12\package.json'
  if ((Test-Path $backendPkg) -and (Test-Path $frontendPkg)) {
    $root = $candidate
    break
  }
}

if (-not $root) {
  Fail 'cannot detect repo root with bn88-backend-v12\package.json and bn88-frontend-dashboard-v12\package.json'
}

function global:cdbnroot { Set-Location $root }
function global:cdbnbe { Set-Location (Join-Path $root 'bn88-backend-v12') }
function global:cdbnfe { Set-Location (Join-Path $root 'bn88-frontend-dashboard-v12') }

Info "root => $root"

$backendDir = Join-Path $root 'bn88-backend-v12'
if (-not (Test-Path (Join-Path $backendDir 'node_modules'))) {
  Info 'backend: node_modules missing -> npm i'
  Push-Location $backendDir
  npm i
  Pop-Location
}

Info 'backend: npm run dev'
$pwshCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } elseif (Get-Command powershell -ErrorAction SilentlyContinue) { 'powershell' } else { $null }
if (-not $pwshCmd) { Fail 'cannot find pwsh/powershell in PATH' }
Start-Process -FilePath $pwshCmd -WorkingDirectory $backendDir -ArgumentList '-NoExit', '-Command', 'npm run dev' | Out-Null

Write-Host 'backend checks:' -ForegroundColor Green
Write-Host '  curl http://127.0.0.1:3000/api/health'
Write-Host '  netstat -ano | findstr :3000'

$frontendDir = Join-Path $root 'bn88-frontend-dashboard-v12'
if (-not (Test-Path (Join-Path $frontendDir 'node_modules'))) {
  Info 'frontend: node_modules missing -> npm i'
  Push-Location $frontendDir
  npm i
  Pop-Location
}

$envFile = Join-Path $frontendDir '.env.local'
'VITE_API_BASE=http://127.0.0.1:3000/api' | Set-Content -Path $envFile -Encoding UTF8
Info "frontend: wrote $envFile"

Info 'frontend: npm run dev'
Start-Process -FilePath $pwshCmd -WorkingDirectory $frontendDir -ArgumentList '-NoExit', '-Command', 'npm run dev' | Out-Null

Write-Host 'tsc checks:' -ForegroundColor Green
Write-Host '  cd bn88-backend-v12; .\node_modules\.bin\tsc.cmd -p tsconfig.json --noEmit'
Write-Host '  cd bn88-frontend-dashboard-v12; .\node_modules\.bin\tsc.cmd -p tsconfig.json --noEmit'
