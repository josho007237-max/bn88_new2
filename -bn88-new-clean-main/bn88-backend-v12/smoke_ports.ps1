param(
  [int]$Port = 4100
)

$ErrorActionPreference = "Stop"

Write-Host "== PORT =="
$net = netstat -ano | Select-String ":$Port\s"
if ($net) {
  $net | ForEach-Object { $_.Line }
} else {
  Write-Host "No listener on port $Port"
}

Write-Host "`n== PROCESS =="
$pid3000 = $null
if ($net) {
  $pid3000 = ($net | Select-Object -First 1).Line.Trim().Split()[-1]
}
if ($pid3000) {
  try {
    Get-Process -Id $pid3000
  } catch {
    Write-Host "Process not found for PID $pid3000"
  }
} else {
  Write-Host "No PID found for port $Port"
}

Write-Host "`n== HEALTH =="
try {
  $health = Invoke-RestMethod "http://127.0.0.1:$Port/health"
  $health | ConvertTo-Json -Depth 4
} catch {
  Write-Host "Health check failed: $($_.Exception.Message)"
}
