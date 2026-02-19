param(
  [string]$BackendPath = (Resolve-Path "$PSScriptRoot/..").Path
)

$ErrorActionPreference = 'Stop'

$envFile = Join-Path $BackendPath '.env'
$exampleFile = Join-Path $BackendPath '.env.example'

if (Test-Path $envFile) {
  Write-Host "[check-env] OK: .env exists at $envFile" -ForegroundColor Green
  exit 0
}

if (-not (Test-Path $exampleFile)) {
  Write-Host "[check-env] ERROR: .env missing and .env.example not found" -ForegroundColor Red
  exit 1
}

Copy-Item -Path $exampleFile -Destination $envFile -Force
Write-Host "[check-env] CREATED: .env copied from .env.example" -ForegroundColor Yellow
Write-Host "[check-env] Please edit .env values before running dev." -ForegroundColor Yellow
