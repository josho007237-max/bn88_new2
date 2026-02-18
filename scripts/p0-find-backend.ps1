param(
  [string]$Root = (Get-Location).Path,
  [int]$Depth = 5
)

$rootResolved = (Resolve-Path $Root).Path
Write-Host ("[p0-find-backend] root = {0}" -f $rootResolved)

$hits = Get-ChildItem -Path $rootResolved -Directory -Recurse -Depth $Depth -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -eq "bn88-backend-v12" } |
  Select-Object -ExpandProperty FullName

if (-not $hits -or $hits.Count -eq 0) {
  Write-Host "[p0-find-backend] NOT FOUND: bn88-backend-v12" -ForegroundColor Yellow
  Write-Host ("Try: dir -Recurse -Directory -Depth {0} | ? Name -eq 'bn88-backend-v12'" -f $Depth)
  exit 1
}

Write-Host "[p0-find-backend] FOUND:" -ForegroundColor Green
$hits | ForEach-Object {
  Write-Host (" - {0}" -f $_)
  Write-Host ("   cd '{0}'" -f $_)
}

# exit 0
