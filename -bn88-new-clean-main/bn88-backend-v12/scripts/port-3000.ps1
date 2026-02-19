#requires -Version 5.1

param(
  [switch]$Kill,
  [int]$Port = 3000
)

$ErrorActionPreference = "Stop"

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

  $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$procId" -ErrorAction SilentlyContinue
  $name = if ($proc) { [string]$proc.Name } else { "" }
  $cmd = if ($proc) { [string]$proc.CommandLine } else { "" }

  if ([string]::IsNullOrWhiteSpace($name)) {
    $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
    if ($p) { $name = [string]$p.ProcessName }
  }

  $rows += [pscustomobject]@{
    Port        = $Port
    PID         = $procId
    ProcessName = $name
    CommandLine = $cmd
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
foreach ($row in $rows) {
  $procId = [int]$row.PID
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
