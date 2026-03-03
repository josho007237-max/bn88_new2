# ===============================================
# BN88 Development Server Shutdown Script
# ===============================================
# Stops processes listening on development ports:
# - 3000 (Backend)
# - 5555 (Frontend)
# - 6380 (Redis docker port binding)
# - 5556..5566 (Prisma Studio / auxiliary dev ports)
# ===============================================

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  BN88 Development Stack Shutdown" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

$ports = @(3000, 5555, 6380) + (5556..5566)
$seenProcesses = @{}
$killed = @()

$dockerProtected = @('com.docker.backend', 'Docker Desktop')
$port6380Busy = Get-NetTCPConnection -LocalPort 6380 -State Listen -ErrorAction SilentlyContinue
if ($port6380Busy) {
    Write-Host "Port 6380 is busy. Trying: docker rm -f bn88-redis" -ForegroundColor Yellow
    docker rm -f bn88-redis 2>$null | Out-Null
    Start-Sleep -Milliseconds 500
    $port6380Busy = Get-NetTCPConnection -LocalPort 6380 -State Listen -ErrorAction SilentlyContinue
    if ($port6380Busy) {
        $dockerOwner = $false
        foreach ($conn in $port6380Busy) {
            $p = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
            if ($p -and ($dockerProtected -contains $p.ProcessName)) { $dockerOwner = $true }
        }
        if ($dockerOwner) {
            Write-Host "Port 6380 is still owned by Docker process. Will NOT kill Docker Desktop/com.docker.backend." -ForegroundColor Yellow
            Write-Host "Please stop Redis container manually (docker rm -f bn88-redis) or free 6380, then retry." -ForegroundColor Yellow
            exit 1
        }
    }
}

foreach ($port in $ports) {
    Write-Host "Checking port $port..." -ForegroundColor Gray
    $connections = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue

    foreach ($conn in $connections) {
        $procId = $conn.OwningProcess
        if (-not $procId) { continue }
        if ($seenProcesses.ContainsKey($procId)) { continue }

        $seenProcesses[$procId] = $true
        $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if (-not $proc) { continue }

        if ($dockerProtected -contains $proc.ProcessName) {
            Write-Host "  -> Skip protected Docker process PID=$procId ($($proc.ProcessName))" -ForegroundColor Yellow
            continue
        }

        Write-Host "  -> Stopping PID=$procId ($($proc.ProcessName))" -ForegroundColor Yellow
        try {
            Stop-Process -Id $procId -Force -ErrorAction Stop
            $killed += [PSCustomObject]@{
                Port = $port
                PID = $procId
                Name = $proc.ProcessName
            }
        } catch {
            Write-Host "  ! Failed to stop PID=$procId : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
if ($killed.Count -eq 0) {
    Write-Host "No matching processes were running." -ForegroundColor Gray
} else {
    Write-Host "Stopped $($killed.Count) process(es):" -ForegroundColor Green
    foreach ($item in $killed) {
        Write-Host "  - PID=$($item.PID) Name=$($item.Name) (detected on port $($item.Port))" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "  Shutdown complete" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
