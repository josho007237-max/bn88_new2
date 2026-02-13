param()

$listenPid3000 = (Get-NetTCPConnection -LocalPort 3000 -State Listen).OwningProcess
if ($listenPid3000 -is [array]) {
  $listenPid3000 = ($listenPid3000 | Where-Object { $_ -gt 0 } | Select-Object -First 1)
}

if (-not $listenPid3000) {
  Write-Host "backend not running" -ForegroundColor Red
  exit 1
}

try {
  $p = Get-CimInstance Win32_Process -Filter "ProcessId=$listenPid3000"
  if (-not $p) { throw "process not found" }

  Write-Host "backend running (pid=$listenPid3000)" -ForegroundColor Green
  Write-Host "ProcessName: $($p.Name)"
  Write-Host "Path: $($p.ExecutablePath)"
  Write-Host "CommandLine: $($p.CommandLine)"
} catch {
  Write-Host "backend running (pid=$listenPid3000)" -ForegroundColor Yellow
  Write-Host "Process details not available" -ForegroundColor Yellow
}
