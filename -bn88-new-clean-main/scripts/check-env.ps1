$ErrorActionPreference = 'Stop'

function Info([string]$Message) {
  Write-Host "[check-env] $Message" -ForegroundColor Cyan
}

function Warn([string]$Message) {
  Write-Host "[check-env] WARN: $Message" -ForegroundColor Yellow
}

$repoRoot = (Resolve-Path (Split-Path -Parent $PSScriptRoot)).Path

$projects = @(
  'bn88-backend-v12',
  'bn88-frontend-dashboard-v12'
)

foreach ($project in $projects) {
  $projectDir = Join-Path $repoRoot $project
  $envPath = Join-Path $projectDir '.env'
  $envExamplePath = Join-Path $projectDir '.env.example'

  if (Test-Path $envPath) {
    Info "$project: found .env"
    continue
  }

  if (Test-Path $envExamplePath) {
    Copy-Item -Path $envExamplePath -Destination $envPath -Force
    Info "$project: created .env from .env.example"
  } else {
    Warn "$project: missing .env and .env.example"
  }
}
