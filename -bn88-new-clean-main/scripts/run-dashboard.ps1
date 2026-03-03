param(
  [string]$Root
)

$ErrorActionPreference = 'Stop'

$searchedRoots = @('C:\BN88', 'C:\Go23_th', 'C:\Users\ADMIN')

if ([string]::IsNullOrWhiteSpace($Root)) {
  $foundDir = $null

  foreach ($base in $searchedRoots) {
    if (-not (Test-Path $base)) { continue }

    $candidate = Get-ChildItem -Path $base -Directory -Recurse -Depth 6 -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -eq 'bn88-frontend-dashboard-v12' } |
      Select-Object -First 1

    if ($candidate) {
      $foundDir = $candidate.FullName
      break
    }
  }

  if (-not $foundDir) {
    throw "ไม่พบโฟลเดอร์ bn88-frontend-dashboard-v12 (ค้นหาแล้วที่: $($searchedRoots -join ', '), Depth=6)"
  }

  $Root = Split-Path -Parent $foundDir
}

$dashboardDir = Join-Path $Root 'bn88-frontend-dashboard-v12'
$packageJson = Join-Path $dashboardDir 'package.json'

Write-Host "ROOT: $Root"
Write-Host "PWD(before): $(Get-Location)"
Write-Host "Test-Path package.json: $(Test-Path $packageJson)"

if (-not (Test-Path $dashboardDir)) {
  throw "ไม่พบโฟลเดอร์ dashboard: $dashboardDir"
}

if (-not (Test-Path $packageJson)) {
  throw "ไม่พบ package.json ที่: $packageJson"
}

Set-Location $dashboardDir
Write-Host "PWD(now): $(Get-Location)"

npm ci
if ($LASTEXITCODE -ne 0) {
  throw 'npm ci failed'
}

npm run dev
if ($LASTEXITCODE -ne 0) {
  throw 'npm run dev failed'
}
