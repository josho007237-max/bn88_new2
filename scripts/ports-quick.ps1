param()

$ErrorActionPreference = 'Stop'

function Get-PortProcessInfo {
  param([int]$Port)

  $hits = netstat -ano | Select-String -Pattern (":{0}\s" -f $Port)
  if (-not $hits -or $hits.Count -eq 0) {
    return @()
  }

  $pids = @()
  foreach ($h in $hits) {
    $parts = $h.Line.Trim() -split '\s+'
    if ($parts.Count -lt 4) { continue }
    $pid = 0
    if ([int]::TryParse($parts[$parts.Count - 1], [ref]$pid) -and $pid -gt 0) {
      $pids += $pid
    }
  }

  $pids = $pids | Sort-Object -Unique
  $rows = foreach ($pid in $pids) {
    $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
    $wmi = Get-CimInstance Win32_Process -Filter "ProcessId=$pid" -ErrorAction SilentlyContinue

    $name = if ($proc) { $proc.ProcessName } else { $wmi.Name }
    $cmd = $null
    if ($name -and $name.ToLower() -eq 'node') {
      $cmd = $wmi.CommandLine
    }

    [pscustomobject]@{
      Port        = $Port
      PID         = $pid
      ProcessName = $name
      CommandLine = $cmd
    }
  }

  return $rows
}

$rows3000 = Get-PortProcessInfo -Port 3000
$rows5555 = Get-PortProcessInfo -Port 5555

if (($rows3000.Count + $rows5555.Count) -eq 0) {
  Write-Host '[ports-quick] no listeners found on :3000 or :5555' -ForegroundColor Yellow
} else {
  Write-Host '[ports-quick] listeners on :3000 / :5555' -ForegroundColor Cyan
  ($rows3000 + $rows5555) | Format-Table -AutoSize Port, PID, ProcessName, CommandLine
}

$whatIs5555 = 'free'
if ($rows5555.Count -gt 0) {
  $withCmd = $rows5555 | Where-Object { $_.CommandLine }
  if ($withCmd) {
    $whatIs5555 = ($withCmd | Select-Object -First 1).CommandLine
  } else {
    $whatIs5555 = ($rows5555 | Select-Object -First 1).ProcessName
  }
}

Write-Host ("Backend=3000, Dashboard/Studio=5555 | 5555 => {0}" -f $whatIs5555) -ForegroundColor Green
