#requires -Version 5.1

<#
  Usage:
    pwsh .\scripts\free_port.ps1 -Port 3000
    pwsh .\scripts\free_port.ps1 -Port 3000 -Kill
#>

param(
  [int]$Port = 3000,
  [switch]$Kill
)

$ErrorActionPreference = "Stop"

function Get-ProcessInfo {
  param([Parameter(Mandatory = $true)][int]$Pid)

  $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$Pid" -ErrorAction SilentlyContinue
  if ($null -ne $proc) {
    return [PSCustomObject]@{
      Pid         = $Pid
      Name        = [string]$proc.Name
      CommandLine = [string]$proc.CommandLine
    }
  }

  $p = Get-Process -Id $Pid -ErrorAction SilentlyContinue
  return [PSCustomObject]@{
    Pid         = $Pid
    Name        = [string]($p?.ProcessName ?? "")
    CommandLine = ""
  }
}

$listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
$pids = @($listeners | Select-Object -ExpandProperty OwningProcess -ErrorAction SilentlyContinue | Where-Object { $_ -gt 0 } | Sort-Object -Unique)

if ($pids.Count -eq 0) {
  Write-Host "No LISTENING TCP process found on port $Port."
  exit 0
}

foreach ($pid in $pids) {
  $info = Get-ProcessInfo -Pid $pid
  Write-Host ("Port {0} -> PID {1}" -f $Port, $info.Pid)
  Write-Host ("Name: {0}" -f $info.Name)
  if ([string]::IsNullOrWhiteSpace($info.CommandLine)) {
    Write-Host "CommandLine: (unavailable)"
  } else {
    Write-Host ("CommandLine: {0}" -f $info.CommandLine)
  }
  Write-Host ""
}

if (-not $Kill) {
  exit 1
}

$failed = $false
foreach ($pid in $pids) {
  & taskkill.exe /PID $pid /F | Out-Null
  if ($LASTEXITCODE -ne 0) { $failed = $true }
}

if ($failed) {
  Write-Error "Found listener(s) on port $Port but failed to kill one or more processes."
  exit 1
}

exit 0

