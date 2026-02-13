param(
  [Parameter(Mandatory = $true)]
  [string]$BackupFile,
  [string]$DbPath = ""
)

$ErrorActionPreference = "Stop"

function Resolve-DbPath([string]$PathArg) {
  if ($PathArg) {
    return (Resolve-Path -Path $PathArg).Path
  }

  $dbUrl = $env:DATABASE_URL
  if ($dbUrl -and $dbUrl.StartsWith("file:")) {
    $raw = $dbUrl.Substring(5)
    return (Resolve-Path -Path $raw).Path
  }

  return (Resolve-Path -Path ".\\dev.db").Path
}

if (-not (Test-Path -Path $BackupFile)) {
  throw "Backup file not found: $BackupFile"
}

$resolvedDb = Resolve-DbPath $DbPath
Copy-Item -Path $BackupFile -Destination $resolvedDb -Force
Write-Host "DB restored -> $resolvedDb"
Write-Host "Reminder: restart the backend after restore."