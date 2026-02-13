# ===============================================
# BN88 Development Server Shutdown Script
# ===============================================
# Stops processes listening on development ports:
# - 3000 (Backend)
# - 5555 (Frontend)
# - 5556..5566 (Prisma Studio / auxiliary dev ports)
# ===============================================

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  BN88 Development Stack Shutdown" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

$ports = @(3000, 5555) + (5556..5566)
$seenProcesses = @{}
$killed = @()

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
