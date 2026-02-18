param(
  [switch]$Reset
)

$ErrorActionPreference = 'Stop'

$backend = (Resolve-Path "$PSScriptRoot/..").Path
$envPath = Join-Path $backend '.env'
if (-not (Test-Path $envPath)) {
  $examplePath = Join-Path $backend '.env.example'
  if (Test-Path $examplePath) {
    Copy-Item $examplePath $envPath -Force
    Write-Host "[p0-fix-db] .env created from .env.example" -ForegroundColor Yellow
  } else {
    Write-Host "[p0-fix-db] ERROR: .env not found" -ForegroundColor Red
    exit 1
  }
}

$raw = Get-Content -Path $envPath -Raw
$line = ($raw -split "`r?`n" | Where-Object { $_ -match '^\s*DATABASE_URL\s*=' } | Select-Object -First 1)
if (-not $line) {
  Write-Host "[p0-fix-db] ERROR: DATABASE_URL not found in .env" -ForegroundColor Red
  exit 1
}

$dbUrl = ($line -replace '^\s*DATABASE_URL\s*=\s*', '').Trim().Trim('"').Trim("'")
Write-Host "[p0-fix-db] DATABASE_URL=$dbUrl"

if ($dbUrl.ToLower().StartsWith('file:')) {
  $dbRel = ($dbUrl.Substring(5) -split '\?')[0]
  if ($dbRel -and $dbRel -ne ':memory:') {
    $dbPath = if ([System.IO.Path]::IsPathRooted($dbRel)) { $dbRel } else { Join-Path $backend $dbRel }
    $dbDir = Split-Path -Parent $dbPath
    if (-not (Test-Path $dbDir)) {
      New-Item -ItemType Directory -Path $dbDir -Force | Out-Null
      Write-Host "[p0-fix-db] created dir: $dbDir"
    }
    if (-not (Test-Path $dbPath)) {
      New-Item -ItemType File -Path $dbPath -Force | Out-Null
      Write-Host "[p0-fix-db] created file: $dbPath"
    }
  }
}

Push-Location $backend
try {
  npx prisma generate
  if ($Reset) {
    npx prisma migrate reset --force --skip-seed
  } else {
    npx prisma migrate deploy
  }
} finally {
  Pop-Location
}

Write-Host "[p0-fix-db] done" -ForegroundColor Green
