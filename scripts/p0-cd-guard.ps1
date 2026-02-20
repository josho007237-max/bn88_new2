$ErrorActionPreference = 'Stop'

$cwd = (Get-Location).Path
$expected = 'C:\Go23_th\bn88_new2\-bn88-new-clean-main\bn88-backend-v12'

if (Test-Path -LiteralPath (Join-Path $cwd 'package.json')) {
  exit 0
}

Write-Host "[p0-cd-guard] WARN: package.json not found in current directory" -ForegroundColor Yellow
Write-Host "[p0-cd-guard] Current: $cwd" -ForegroundColor Yellow
Write-Host "[p0-cd-guard] Copy/Paste:" -ForegroundColor Cyan
Write-Host (('cd "{0}"' -f $expected)) -ForegroundColor Cyan
exit 1
