#requires -Version 5.1

param(
  [switch]$Kill
)

$ErrorActionPreference = "Stop"
$Port = 3000

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

if ($pids.Count -gt 1) {
  Write-Warning "มี dev ซ้อน: พบหลาย PID จับพอร์ต $Port"
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

if (-not $Kill) {
  exit 0
}

$failed = $false
foreach ($pid in $pids) {
  & taskkill.exe /PID $pid /F | Out-Null
  if ($LASTEXITCODE -ne 0) { $failed = $true }
}

if ($failed) {
  Write-Error "Failed to kill one or more PID(s) on port $Port."
  exit 1
}

Write-Host "Killed listener(s) on port $Port."
exit 0
