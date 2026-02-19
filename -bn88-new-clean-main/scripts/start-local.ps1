$ErrorActionPreference = 'Stop'

function Info([string]$Message) {
  Write-Host "[start-local] $Message" -ForegroundColor Cyan
}

function Fail([string]$Message) {
  Write-Host "[start-local] ERROR: $Message" -ForegroundColor Red
  exit 1
}

$root = 'C:\Go23_th\bn88_new2\-bn88-new-clean-main'
if (-not (Test-Path $root)) { Fail 'missing repo root C:\Go23_th\bn88_new2\-bn88-new-clean-main' }

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
Write-Host 'Open local links:' -ForegroundColor Green
Write-Host '  Frontend: http://127.0.0.1:5555'
Write-Host '  Backend health: http://127.0.0.1:3000/api/health'
Write-Host ''
Write-Host 'Copy/Paste smoke checks:' -ForegroundColor Green
Write-Host 'curl http://127.0.0.1:3000/api/health'
Write-Host '$body = @{ email = "root@bn9.local"; password = "bn9@12345" } | ConvertTo-Json'
Write-Host '$token = (Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:3000/api/admin/auth/login" -ContentType "application/json" -Body $body).token'
Write-Host 'Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:3000/api/admin/bots" -Headers @{ Authorization = "Bearer $token"; "x-tenant" = "bn9" }'
