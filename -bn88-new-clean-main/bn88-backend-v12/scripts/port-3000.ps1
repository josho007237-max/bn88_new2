#requires -Version 5.1

param(
  [switch]$Kill,
  [int]$Port = 3000
)

$ErrorActionPreference = "Stop"

$listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
$processIds = @(
  $listeners |
    Select-Object -ExpandProperty OwningProcess -ErrorAction SilentlyContinue |
    Where-Object { $_ -gt 0 } |
    Sort-Object -Unique
)

if ($processIds.Count -eq 0) {
  Write-Host "No LISTENING TCP process found on port $Port."
  exit 0
}

if ($processIds.Count -gt 1) {
  Write-Warning "มี dev ซ้อน: พบหลาย PID จับพอร์ต $Port"
}

foreach ($procId in $processIds) {
  $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$procId" -ErrorAction SilentlyContinue
  $name = if ($proc) { [string]$proc.Name } else { "" }
  $cmd = if ($proc) { [string]$proc.CommandLine } else { "" }

  if ([string]::IsNullOrWhiteSpace($name)) {
    $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
    $name = [string]($p?.ProcessName ?? "")
  }

  Write-Host ("Port {0} -> PID {1}" -f $Port, $procId)
  Write-Host ("Name: {0}" -f $name)
  if ([string]::IsNullOrWhiteSpace($cmd)) {
    Write-Host "CommandLine: (unavailable)"
  } else {
    Write-Host ("CommandLine: {0}" -f $cmd)
  }
  Write-Host ""
}

if (-not $Kill) {
  exit 0
}

$failed = $false
foreach ($procId in $processIds) {
  try {
    Stop-Process -Id $procId -Force -ErrorAction Stop
    Write-Host ("Killed PID {0}" -f $procId)
  } catch {
    Write-Warning ("Failed to kill PID {0}: {1}" -f $procId, $_.Exception.Message)
    $failed = $true
  }
}

if ($failed) {
  Write-Error "Failed to kill one or more PID(s) on port $Port."
  exit 1
}

Write-Host "Killed listener(s) on port $Port."
exit 0
