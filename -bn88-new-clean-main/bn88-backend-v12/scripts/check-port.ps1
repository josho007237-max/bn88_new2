#requires -Version 5.1

param(
  [int]$Port = 3000
)

$ErrorActionPreference = "Stop"

$listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
$pids = @(
  $listeners |
    Select-Object -ExpandProperty OwningProcess -ErrorAction SilentlyContinue |
    Where-Object { $_ -gt 0 } |
    Sort-Object -Unique
)

if ($pids.Count -eq 0) {
  Write-Host "No LISTENING TCP process found on port $Port."
  exit 0
}

foreach ($pid in $pids) {
  $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$pid" -ErrorAction SilentlyContinue
  $name = if ($proc) { [string]$proc.Name } else { "" }
  $cmd = if ($proc) { [string]$proc.CommandLine } else { "" }

  if ([string]::IsNullOrWhiteSpace($name)) {
    $p = Get-Process -Id $pid -ErrorAction SilentlyContinue
    $name = [string]($p?.ProcessName ?? "")
  }

  Write-Host ("Port {0} -> PID {1}" -f $Port, $pid)
  Write-Host ("Name: {0}" -f $name)
  if ([string]::IsNullOrWhiteSpace($cmd)) {
    Write-Host "CommandLine: (unavailable)"
  } else {
    Write-Host ("CommandLine: {0}" -f $cmd)
  }
  Write-Host ""
}

exit 0
