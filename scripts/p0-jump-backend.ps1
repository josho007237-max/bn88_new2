param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot/..").Path
)

$ErrorActionPreference = 'Stop'

$mainRoot = Join-Path $RepoRoot '-bn88-new-clean-main'
if (-not (Test-Path $mainRoot)) {
  Write-Host "[p0-jump-backend] not found: $mainRoot"
  exit 1
}

$hits = Get-ChildItem -LiteralPath $mainRoot -Directory -Recurse -Depth 3 -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -eq 'bn88-backend-v12' } |
  Select-Object -ExpandProperty FullName -Unique

if (-not $hits -or $hits.Count -eq 0) {
  Write-Host "[p0-jump-backend] bn88-backend-v12 not found under $mainRoot"
  exit 1
}

$backend = $hits[0]
Write-Host "[p0-jump-backend] backend path: $backend"
Set-Location -LiteralPath $backend
Write-Host "[p0-jump-backend] cwd: $(Get-Location)"

$serverTs = Join-Path $backend 'src/server.ts'
$ok = Test-Path $serverTs
Write-Host "[p0-jump-backend] Test-Path src/server.ts => $ok"
if (-not $ok) {
  exit 1
}

Write-Host "`n== mount points (/api/webhooks*, /api/admin*) =="
Select-String -Path $serverTs -Pattern '/api/webhooks|/api/admin' |
  ForEach-Object {
    $line = $_.Line.Trim()
    Write-Host ("src/server.ts:{0}: {1}" -f $_.LineNumber, $line)
  }
