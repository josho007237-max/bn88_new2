param(
  [string]$Root = (Get-Location).Path,
  [int]$Depth = 5
)

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force | Out-Null
$ErrorActionPreference = 'Stop'

$rootResolved = (Resolve-Path $Root).Path
Write-Host ("[p0-bootstrap] root = {0}" -f $rootResolved)

$hits = Get-ChildItem -Path $rootResolved -Directory -Recurse -Depth $Depth -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -eq 'bn88-backend-v12' } |
  Select-Object -ExpandProperty FullName

if (-not $hits -or $hits.Count -eq 0) {
  Write-Host "[p0-bootstrap] NOT FOUND: bn88-backend-v12" -ForegroundColor Yellow
  Write-Host ("Try: dir -Recurse -Directory -Depth {0} | ? Name -eq 'bn88-backend-v12'" -f $Depth)
  exit 1
}

$backend = $hits[0]
Write-Host ("[p0-bootstrap] backend = {0}" -f $backend) -ForegroundColor Green
Set-Location -LiteralPath $backend
Write-Host ("[p0-bootstrap] cwd = {0}" -f (Get-Location).Path)

if (-not (Test-Path (Join-Path $backend 'node_modules'))) {
  Write-Host "[p0-bootstrap] node_modules missing -> npm ci" -ForegroundColor Cyan
  npm ci
} else {
  Write-Host "[p0-bootstrap] node_modules exists -> skip npm ci"
}

Write-Host "`n[p0-bootstrap] next commands:" -ForegroundColor Cyan
Write-Host "  npm run dev"
Write-Host "  npm run port:3000"
Write-Host "  curl http://localhost:3000/api/health"
