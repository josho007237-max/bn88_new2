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

$dockerReady = $false
try {
    $null = docker version --format '{{.Server.Version}}' 2>$null
    if ($LASTEXITCODE -eq 0) {
        $dockerReady = $true
    }
} catch {
    $dockerReady = $false
}

if (-not $dockerReady) {
    Write-Host "WARN: Docker Desktop is not ready; Redis container (port 6380) may not start and quick-check may FAIL on 6380." -ForegroundColor Yellow
    Write-Host "      Fix: Start Docker Desktop, then rerun .\start-dev.ps1" -ForegroundColor Yellow
}


# Guard: avoid duplicate runs on required ports
$requiredPorts = @(3000, 5555, 6380)
$busy = @()
foreach ($port in $requiredPorts) {
    $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $conn) { continue }

    if ($port -eq 6380) {
        $redisRunning = (docker ps --filter "name=^/bn88-redis$" --format "{{.Names}}" 2>$null)
        if ($redisRunning -match '^bn88-redis$') {
            Write-Host "WARN: port 6380 is in use by running container 'bn88-redis' (allowed)." -ForegroundColor Yellow
            Write-Host "      If you need a clean restart: .\stop-dev.ps1 (this will docker rm -f bn88-redis)" -ForegroundColor Yellow
            continue
        }
    }

    $busy += $port
}
if ($busy.Count -gt 0) {
    Write-Host "ERROR: Detected active listener(s) on port(s): $($busy -join ', ')" -ForegroundColor Red
    Write-Host "Please run .\stop-dev.ps1 first, then start again." -ForegroundColor Yellow
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

$secretLine = $null
if (Test-Path $backendEnv) {
    $secretLine = Get-Content $backendEnv | Where-Object { $_ -match '^SECRET_ENC_KEY_BN9=' } | Select-Object -First 1
}
$secretValue = if ($secretLine) { ($secretLine -split '=', 2)[1].Trim() } else { '' }
if (-not $secretValue -or $secretValue.Length -ne 32) {
    Write-Host "ERROR: Missing/invalid SECRET_ENC_KEY_BN9 (must be 32 chars) in $backendEnv" -ForegroundColor Red
    Write-Host "Fix: cd bn88-backend-v12; node .\scripts\gen-dev-secret-key.mjs" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Starting development servers..." -ForegroundColor Cyan
Write-Host ""

if ($dockerReady) {
    $redisRunning = (docker ps --filter "name=^/bn88-redis$" --format "{{.Names}}" 2>$null)
    if (-not ($redisRunning -match '^bn88-redis$')) {
        Write-Host "Starting Redis container (bn88-redis, port 6380)..." -ForegroundColor Green
        $null = docker rm -f bn88-redis 2>$null
        $null = docker run -d --name bn88-redis -p 6380:6379 redis:8-alpine 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Redis container started" -ForegroundColor Green
        } else {
            Write-Host "WARN: Failed to start Redis container; port 6380 checks may FAIL." -ForegroundColor Yellow
        }
    }
}

# Backend window
Write-Host "Starting Backend Server (Port 3000)..." -ForegroundColor Green
$backendCommand = "cd `"$backendPath`"; Write-Host '=== BN88 Backend Server ===' -ForegroundColor Cyan; Write-Host 'Port: 3000' -ForegroundColor Green; Write-Host ''; npm run dev"
Start-Process pwsh -ArgumentList "-NoExit", "-Command", $backendCommand

$backendReady = $false
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 500
    $listen3000 = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($listen3000) { $backendReady = $true; break }
}
if (-not $backendReady) {
    Write-Host "ERROR: Backend did not bind to :3000 in time (possible crash)." -ForegroundColor Red
    Write-Host "Manual run: cd bn88-backend-v12; npm run dev" -ForegroundColor Yellow
    exit 1
}

# Frontend window
Write-Host "Starting Frontend Server (Port 5555)..." -ForegroundColor Green
$frontendCommand = "cd `"$frontendPath`"; Write-Host '=== BN88 Frontend Dashboard ===' -ForegroundColor Cyan; Write-Host 'Port: 5555' -ForegroundColor Green; Write-Host ''; npm run dev -- --port 5555"
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
