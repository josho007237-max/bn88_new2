$ErrorActionPreference = 'Stop'

function Info([string]$Message) {
  Write-Host "[go-bn88] $Message" -ForegroundColor Cyan
}

function Fail([string]$Message) {
  Write-Host "[go-bn88] ERROR: $Message" -ForegroundColor Red
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

$repoRoot = $null
foreach ($candidate in $candidates) {
  if (-not $candidate) { continue }
  $backendPkg = Join-Path $candidate 'bn88-backend-v12\package.json'
  $frontendPkg = Join-Path $candidate 'bn88-frontend-dashboard-v12\package.json'
  if ((Test-Path $backendPkg) -and (Test-Path $frontendPkg)) {
    $repoRoot = $candidate
    break
  }
}

if (-not $repoRoot) {
  Fail 'cannot find repo root with bn88-backend-v12\package.json and bn88-frontend-dashboard-v12\package.json'
}

Info "repo root => $repoRoot"

$backendDir = Join-Path $repoRoot 'bn88-backend-v12'
$frontendDir = Join-Path $repoRoot 'bn88-frontend-dashboard-v12'

$pwshCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } elseif (Get-Command powershell -ErrorAction SilentlyContinue) { 'powershell' } else { $null }
if (-not $pwshCmd) { Fail 'cannot find pwsh/powershell in PATH' }

if (-not (Test-Path (Join-Path $backendDir 'node_modules'))) {
  Info 'install backend dependencies (npm i)'
  Push-Location $backendDir
  npm i
  Pop-Location
}

if (-not (Test-Path (Join-Path $frontendDir 'node_modules'))) {
  Info 'install frontend dependencies (npm i)'
  Push-Location $frontendDir
  npm i
  Pop-Location
}

$frontendEnvFile = Join-Path $frontendDir '.env.local'
"VITE_API_BASE=http://127.0.0.1:3000/api" | Set-Content -Path $frontendEnvFile -Encoding UTF8
Info "write $frontendEnvFile"

Info 'start backend => npm run dev'
Start-Process -FilePath $pwshCmd -WorkingDirectory $backendDir -ArgumentList '-NoExit', '-Command', 'npm run dev' | Out-Null

Info 'start frontend => npm run dev'
Start-Process -FilePath $pwshCmd -WorkingDirectory $frontendDir -ArgumentList '-NoExit', '-Command', 'npm run dev' | Out-Null

Write-Host ''
Write-Host 'Copy/Paste smoke commands:' -ForegroundColor Green
Write-Host "curl http://127.0.0.1:3000/api/health"
Write-Host '$body = @{ email = "root@bn9.local"; password = "bn9@12345" } | ConvertTo-Json'
Write-Host '$token = (Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:3000/api/admin/auth/login" -ContentType "application/json" -Body $body).token'
Write-Host 'Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:3000/api/admin/bots" -Headers @{ Authorization = "Bearer $token"; "x-tenant" = "bn9" }'
