param(
  [string]$BackendPath = (Resolve-Path "$PSScriptRoot/..").Path
)

$ErrorActionPreference = 'Stop'

$envFile = Join-Path $BackendPath '.env'
$exampleFile = Join-Path $BackendPath '.env.example'

if (-not (Test-Path -Path $envFile)) {
  if (-not (Test-Path -Path $exampleFile)) {
    Write-Host "[check-env] ERROR: .env missing and .env.example not found" -ForegroundColor Red
    exit 1
  }

  Copy-Item -Path $exampleFile -Destination $envFile -Force
  Write-Host "[check-env] CREATED: .env copied from .env.example" -ForegroundColor Yellow
}

function Ensure-EnvKey {
  param(
    [string]$Path,
    [string]$Key,
    [string]$Value
  )

  $pattern = "^\s*" + [regex]::Escape($Key) + "\s*="
  $exists = Select-String -Path $Path -Pattern $pattern -SimpleMatch:$false -Quiet
  if ($exists) { return }

  Add-Content -Path $Path -Value ("{0}={1}" -f $Key, $Value)
  Write-Host ("[check-env] added {0}={1}" -f $Key, $Value) -ForegroundColor Cyan
}

# required local-dev keys (append only if missing)
Ensure-EnvKey -Path $envFile -Key 'ENABLE_ADMIN_API' -Value '1'
Ensure-EnvKey -Path $envFile -Key 'ENABLE_DEV_ROUTES' -Value '1'
Ensure-EnvKey -Path $envFile -Key 'JWT_SECRET' -Value 'bn9_dev_secret_change_in_production'
Ensure-EnvKey -Path $envFile -Key 'JWT_EXPIRE' -Value '7d'
Ensure-EnvKey -Path $envFile -Key 'NODE_ENV' -Value 'development'
Ensure-EnvKey -Path $envFile -Key 'PORT' -Value '3000'

Write-Host "[check-env] OK: .env bootstrap complete" -ForegroundColor Green
Write-Host "[check-env] NOTE: SECRET_ENC_KEY_BN9 is kept unchanged." -ForegroundColor Green
