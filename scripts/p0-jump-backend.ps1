param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot/..").Path
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$candidates = @(
  (Join-Path $repoRoot '-bn88-new-clean-main\bn88-backend-v12'),
  (Join-Path $repoRoot 'bn88-backend-v12')
)

$backend = $candidates |
  Where-Object { Test-Path -LiteralPath (Join-Path $_ 'package.json') } |
  Select-Object -First 1

if (-not $backend) {
  Write-Host "[p0-jump-backend] backend not found (missing package.json in candidates)" -ForegroundColor Yellow
  Write-Host "[p0-jump-backend] please cd to the correct backend path and run again" -ForegroundColor Yellow
  exit 1
}

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
