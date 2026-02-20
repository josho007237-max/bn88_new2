$ErrorActionPreference = 'Stop'

$cwd = (Get-Location).Path
$expected = 'C:\Go23_th\bn88_new2\-bn88-new-clean-main\bn88-backend-v12'

if (Test-Path -LiteralPath (Join-Path $cwd 'package.json')) {
  Write-Host "[p0-cd-guard] OK: package.json found at $cwd" -ForegroundColor Green
  exit 0
}

Write-Host "[p0-cd-guard] WARN: package.json not found in current directory" -ForegroundColor Yellow
Write-Host "[p0-cd-guard] Current: $cwd" -ForegroundColor Yellow
Write-Host "[p0-cd-guard] Please cd to: $expected" -ForegroundColor Cyan
exit 1
