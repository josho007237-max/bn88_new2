# ===============================================
# BN88 Development Server Startup Script
# ===============================================
# Starts backend and frontend in separate PowerShell windows
# ===============================================

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  BN88 Development Stack Startup" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Get repo root (script location)
$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Write-Host "Project root: $root" -ForegroundColor Gray

# Paths
$backendPath = Join-Path $root "bn88-backend-v12"
$frontendPath = Join-Path $root "bn88-frontend-dashboard-v12"

# Verify directories exist
if (-not (Test-Path $backendPath)) {
    Write-Host "ERROR: Backend directory not found at: $backendPath" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $frontendPath)) {
    Write-Host "ERROR: Frontend directory not found at: $frontendPath" -ForegroundColor Red
    exit 1
}

Write-Host "Checking environment files..." -ForegroundColor Yellow

# Ensure .env files exist; create from .env.example if missing
$backendEnv = Join-Path $backendPath ".env"
$frontendEnv = Join-Path $frontendPath ".env"

if (-not (Test-Path $backendEnv)) {
    $backendEnvExample = Join-Path $backendPath ".env.example"
    if (Test-Path $backendEnvExample) {
        Copy-Item $backendEnvExample $backendEnv
        Write-Host "  ✓ Created $backendEnv" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: Backend .env.example not found" -ForegroundColor Red
    }
}

if (-not (Test-Path $frontendEnv)) {
    $frontendEnvExample = Join-Path $frontendPath ".env.example"
    if (Test-Path $frontendEnvExample) {
        Copy-Item $frontendEnvExample $frontendEnv
        Write-Host "  ✓ Created $frontendEnv" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: Frontend .env.example not found" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Starting development servers..." -ForegroundColor Cyan
Write-Host ""

# Backend window
Write-Host "Starting Backend Server (Port 3000)..." -ForegroundColor Green
$backendCommand = "cd `"$backendPath`"; Write-Host '=== BN88 Backend Server ===' -ForegroundColor Cyan; Write-Host 'Port: 3000' -ForegroundColor Green; Write-Host ''; npm run dev"
Start-Process pwsh -ArgumentList "-NoExit", "-Command", $backendCommand

Start-Sleep -Seconds 2

# Frontend window
Write-Host "Starting Frontend Server (Port 5555)..." -ForegroundColor Green
$frontendCommand = "cd `"$frontendPath`"; Write-Host '=== BN88 Frontend Dashboard ===' -ForegroundColor Cyan; Write-Host 'Port: 5555' -ForegroundColor Green; Write-Host ''; npm run dev"
Start-Process pwsh -ArgumentList "-NoExit", "-Command", $frontendCommand

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "  Development servers started successfully!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Backend:  http://localhost:3000" -ForegroundColor Yellow
Write-Host "Frontend: http://localhost:5555" -ForegroundColor Yellow
Write-Host "Health:   http://localhost:3000/api/health" -ForegroundColor Yellow
Write-Host ""
Write-Host "Default Login Credentials:" -ForegroundColor Cyan
Write-Host "  Email:    root@bn9.local" -ForegroundColor White
Write-Host "  Password: bn9@12345" -ForegroundColor White
Write-Host "  Tenant:   bn9" -ForegroundColor White
Write-Host ""
Write-Host "To stop all services, run: .\stop-dev.ps1" -ForegroundColor Gray
Write-Host "===============================================" -ForegroundColor Green
