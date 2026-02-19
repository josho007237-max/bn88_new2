param(
  [int]$Port = 5555
)

$ErrorActionPreference = 'Stop'

if ($Port -le 0 -or $Port -gt 65535) {
  Write-Host "[who-uses-port] ERROR: invalid port $Port" -ForegroundColor Red
  exit 1
}

Write-Host "[who-uses-port] scanning port $Port via netstat -ano" -ForegroundColor Cyan

$lines = netstat -ano | Select-String -Pattern (":{0}\s" -f $Port)
if (-not $lines -or $lines.Count -eq 0) {
  Write-Host "[who-uses-port] port $Port is free" -ForegroundColor Green
  exit 0
}

$pids = @()
foreach ($line in $lines) {
  $text = $line.Line.Trim()
  if (-not $text) { continue }

  $parts = $text -split '\s+'
  if ($parts.Count -lt 4) { continue }

  $pidRaw = $parts[$parts.Count - 1]
  $pid = 0
  if ([int]::TryParse($pidRaw, [ref]$pid) -and $pid -gt 0) {
    $pids += $pid
  }
}

$pids = $pids | Sort-Object -Unique
if (-not $pids -or $pids.Count -eq 0) {
  Write-Host "[who-uses-port] port $Port is free" -ForegroundColor Green
  exit 0
}

Write-Host "[who-uses-port] found PID(s): $($pids -join ', ')" -ForegroundColor Yellow

$result = foreach ($pid in $pids) {
  $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
  $wmi = Get-CimInstance Win32_Process -Filter "ProcessId=$pid" -ErrorAction SilentlyContinue

  [pscustomobject]@{
    PID         = $pid
    ProcessName = if ($proc) { $proc.ProcessName } else { $wmi.Name }
    Path        = $wmi.ExecutablePath
    StartTime   = if ($proc) { $proc.StartTime } else { $null }
    CommandLine = $wmi.CommandLine
  }
}

$result | Format-Table -AutoSize PID, ProcessName, Path, StartTime, CommandLine
