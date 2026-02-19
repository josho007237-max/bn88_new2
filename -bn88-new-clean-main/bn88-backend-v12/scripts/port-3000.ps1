#requires -Version 5.1

param(
  [switch]$Kill,
  [int]$Port = 3000
)

$ErrorActionPreference = "Stop"
 codex/audit-and-fix-plan-for-bn88-backend-v12-f3hoo6

$rows = @()
$lines = @(netstat -ano -p tcp)

foreach ($line in $lines) {
  $trim = ($line | Out-String).Trim()
  if (-not $trim) { continue }
  if ($trim -notmatch '^\s*TCP\s+') { continue }
  if ($trim -notmatch ':\d+\s+') { continue }

  $parts = $trim -split '\s+'
  if ($parts.Count -lt 5) { continue }

  $localAddress = $parts[1]
  $state = $parts[3]
  $pidText = $parts[4]

  if ($state -ne 'LISTENING') { continue }
  if ($localAddress -notmatch ":$Port$") { continue }

  $procId = 0
  [void][int]::TryParse($pidText, [ref]$procId)
  if ($procId -le 0) { continue }


codex/audit-and-fix-plan-for-bn88-backend-v12-ffzxx8

$rows = @()
$lines = @(netstat -ano -p tcp)

foreach ($line in $lines) {
  $trim = ($line | Out-String).Trim()
  if (-not $trim) { continue }
  if ($trim -notmatch '^\s*TCP\s+') { continue }
  if ($trim -notmatch ':\d+\s+') { continue }

  $parts = $trim -split '\s+'
  if ($parts.Count -lt 5) { continue }

  $localAddress = $parts[1]
  $state = $parts[3]
  $pidText = $parts[4]

  if ($state -ne 'LISTENING') { continue }
  if ($localAddress -notmatch ":$Port$") { continue }

  $procId = 0
  [void][int]::TryParse($pidText, [ref]$procId)
  if ($procId -le 0) { continue }


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
main
 main
  $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$procId" -ErrorAction SilentlyContinue
  $name = if ($proc) { [string]$proc.Name } else { "" }
  $cmd = if ($proc) { [string]$proc.CommandLine } else { "" }

  if ([string]::IsNullOrWhiteSpace($name)) {
    $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
 codex/audit-and-fix-plan-for-bn88-backend-v12-f3hoo6
    if ($p) { $name = [string]$p.ProcessName }
  }

  $rows += [pscustomobject]@{
    Port        = $Port
    PID         = $procId
    ProcessName = $name
    CommandLine = $cmd
=======
codex/audit-and-fix-plan-for-bn88-backend-v12-ffzxx8
    if ($p) { $name = [string]$p.ProcessName }
  }

  $rows += [pscustomobject]@{
    Port        = $Port
    PID         = $procId
    ProcessName = $name
    CommandLine = $cmd
=======
    $name = [string]($p?.ProcessName ?? "")
  }

  Write-Host ("Port {0} -> PID {1}" -f $Port, $procId)
  Write-Host ("Name: {0}" -f $name)
  if ([string]::IsNullOrWhiteSpace($cmd)) {
    Write-Host "CommandLine: (unavailable)"
  } else {
    Write-Host ("CommandLine: {0}" -f $cmd)
main
main
  }
}

$rows = @($rows | Sort-Object PID -Unique)

if ($rows.Count -eq 0) {
  Write-Host "No LISTENING TCP process found on port $Port."
  exit 0
}

$rows | Format-Table -AutoSize Port, PID, ProcessName, CommandLine

if (-not $Kill) {
  exit 0
}

$failed = $false
 codex/audit-and-fix-plan-for-bn88-backend-v12-f3hoo6
foreach ($row in $rows) {
  $procId = [int]$row.PID
=======
codex/audit-and-fix-plan-for-bn88-backend-v12-ffzxx8
foreach ($row in $rows) {
  $procId = [int]$row.PID
=======
foreach ($procId in $processIds) {
main
 main
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
