$ErrorActionPreference = "Stop"
$dbPath = Join-Path $PSScriptRoot "..\\..\\prisma\\dev.db"
if (-not (Test-Path $dbPath)) {
  Write-Host "Database not found: $dbPath"
  exit 1
}

$hasDuplicates = $false
function CheckTable($table) {
  $sql = "SELECT botId, COUNT(*) AS cnt FROM $table GROUP BY botId HAVING cnt > 1;"
  $result = & sqlite3.exe $dbPath $sql
  if ($result) {
    Write-Host "Duplicate entries in $table:" -ForegroundColor Yellow
    $result -split "\n" | ForEach-Object {
      $parts = $_ -split "\|"
      $botId = $parts[0]
      $count = $parts[1]
      Write-Host "  botId=$botId (count=$count)"
    }
    $global:hasDuplicates = $true
  } else {
    Write-Host "No duplicates in $table"
  }
}

CheckTable "BotSecret"
CheckTable "BotConfig"

if ($hasDuplicates) {
  Write-Host "P0 DB audit detected duplicates" -ForegroundColor Red
  exit 1
}
Write-Host "P0 DB audit clean" -ForegroundColor Green
