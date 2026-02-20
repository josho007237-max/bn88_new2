$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$fePath = Join-Path $repoRoot '-bn88-new-clean-main\bn88-frontend-dashboard-v12'
if (-not (Test-Path -LiteralPath $fePath)) {
  $fePath = Join-Path $repoRoot 'bn88-frontend-dashboard-v12'
}
if (-not (Test-Path -LiteralPath $fePath)) {
  Write-Host "[p1-fe-bootstrap] frontend path not found" -ForegroundColor Yellow
  exit 1
}

Set-Location -LiteralPath $fePath
Write-Host "[p1-fe-bootstrap] cwd: $fePath"

npm config set registry https://registry.npmjs.org/
npm config set audit false
npm config set fund false
npm config set progress false

$lockPath = Join-Path $fePath 'package-lock.json'
if (Test-Path -LiteralPath $lockPath) {
  npm ci --no-audit --no-fund
} else {
  npm install --no-audit --no-fund
}

try {
  npm run dev
} catch {
  Write-Host '[p1-fe-bootstrap] npm run dev failed; showing latest npm-cache log...' -ForegroundColor Yellow
  $logRoot = Join-Path $env:APPDATA 'npm-cache\_logs'
  $latestLog = Get-ChildItem -LiteralPath $logRoot -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if ($latestLog) {
    Write-Host "[p1-fe-bootstrap] latest log: $($latestLog.FullName)" -ForegroundColor Cyan
    Get-Content -LiteralPath $latestLog.FullName -Tail 120
  } else {
    Write-Host '[p1-fe-bootstrap] no npm log found under %APPDATA%\npm-cache\_logs' -ForegroundColor Yellow
  }
  throw
}
