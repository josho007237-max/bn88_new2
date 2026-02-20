$ErrorActionPreference = 'Stop'

$cwd = (Get-Location).Path
$repoRoot = Split-Path -Parent $PSScriptRoot
$expected = Join-Path $repoRoot '-bn88-new-clean-main\bn88-backend-v12'

if (Test-Path -LiteralPath (Join-Path $cwd 'package.json')) {
  exit 0
}

Write-Host "[p0-cd-guard] WARN: package.json not found in current directory" -ForegroundColor Yellow
Write-Host "[p0-cd-guard] Current: $cwd" -ForegroundColor Yellow
Write-Host "[p0-cd-guard] Copy/Paste:" -ForegroundColor Cyan
Write-Host "cd `"$expected`"" -ForegroundColor Cyan
exit 1
