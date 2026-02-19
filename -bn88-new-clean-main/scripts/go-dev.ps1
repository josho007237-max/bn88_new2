$ErrorActionPreference = 'Stop'

function Info([string]$Message) {
  Write-Host "[go-dev] $Message" -ForegroundColor Cyan
}

function Fail([string]$Message) {
  Write-Host "[go-dev] ERROR: $Message" -ForegroundColor Red
  exit 1
}

$searchBase = 'C:\Go23_th\bn88_new2'
$root = $null

$candidates = @($searchBase)
if (Test-Path $searchBase) {
  $candidates += @(Get-ChildItem -Path $searchBase -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
}

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
  Fail 'cannot detect repo root under C:\Go23_th\bn88_new2 with bn88-backend-v12\package.json and bn88-frontend-dashboard-v12\package.json'
}

Set-Location $root
function global:cdbnbe { Set-Location (Join-Path $root 'bn88-backend-v12') }
function global:cdbnfe { Set-Location (Join-Path $root 'bn88-frontend-dashboard-v12') }
Info "root => $root"

$pwshCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } elseif (Get-Command powershell -ErrorAction SilentlyContinue) { 'powershell' } else { $null }
if (-not $pwshCmd) { Fail 'cannot find pwsh/powershell in PATH' }

$backendDir = Join-Path $root 'bn88-backend-v12'
if (-not (Test-Path (Join-Path $backendDir 'node_modules'))) {
  Info 'backend: node_modules missing -> npm i'
  Push-Location $backendDir
  npm i
  Pop-Location
}
Info 'backend: npm run dev'
Start-Process -FilePath $pwshCmd -WorkingDirectory $backendDir -ArgumentList '-NoExit', '-Command', 'npm run dev' | Out-Null

$frontendDir = Join-Path $root 'bn88-frontend-dashboard-v12'
if (-not (Test-Path (Join-Path $frontendDir 'node_modules'))) {
  Info 'frontend: node_modules missing -> npm i'
  Push-Location $frontendDir
  npm i
  Pop-Location
}
'VITE_API_BASE=http://127.0.0.1:3000/api' | Set-Content -Path (Join-Path $frontendDir '.env.local') -Encoding UTF8
Info 'frontend: npm run dev'
Start-Process -FilePath $pwshCmd -WorkingDirectory $frontendDir -ArgumentList '-NoExit', '-Command', 'npm run dev' | Out-Null

Write-Host ''
Write-Host 'Copy/Paste checks:' -ForegroundColor Green
Write-Host 'netstat -ano | findstr :3000'
Write-Host 'curl http://127.0.0.1:3000/api/health'
Write-Host '$body = @{ email = "root@bn9.local"; password = "bn9@12345" } | ConvertTo-Json'
Write-Host '$token = (Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:3000/api/admin/auth/login" -ContentType "application/json" -Body $body).token'
Write-Host 'Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:3000/api/admin/bots" -Headers @{ Authorization = "Bearer $token"; "x-tenant" = "bn9" }'
