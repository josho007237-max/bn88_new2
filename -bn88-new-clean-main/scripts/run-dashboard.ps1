param(
  [string]$Root
)

$ErrorActionPreference = 'Stop'

$searchOrder = @('C:\Go23_th', 'C:\BN88', 'C:\Users\ADMIN')
$searchedNotes = @()
$rootProvided = $PSBoundParameters.ContainsKey('Root')

if (-not $rootProvided) {
  Write-Host "Searching roots: $($searchOrder -join ', ')"

  $found = @()
  foreach ($base in $searchOrder) {
    if (-not (Test-Path $base)) {
      $searchedNotes += "$base (missing)"
      continue
    }

    $searchedNotes += "$base (where.exe /r package.json + findstr)"
    $whereResults = @(where.exe /r $base package.json 2>$null)
    if ($whereResults.Count -eq 0) { continue }

    $filtered = @($whereResults | findstr /R /I "bn88-frontend-dashboard-v12\\package.json$")
    foreach ($line in $filtered) {
      $pkgPath = "$line".Trim()
      if (-not [string]::IsNullOrWhiteSpace($pkgPath) -and (Test-Path $pkgPath)) {
        $found += $pkgPath
      }
    }
  }

  $found = @($found | Select-Object -Unique)
  if ($found.Count -gt 0) {
    Write-Host 'Found package.json candidates:'
    $found | ForEach-Object { Write-Host "  - $_" }
  }

  if ($found.Count -eq 0) {
    throw "ไม่พบ bn88-frontend-dashboard-v12\package.json; ค้นแล้ว: $($searchedNotes -join '; '). แนะนำให้รันด้วย -Root <path> (โฟลเดอร์แม่ที่มี bn88-frontend-dashboard-v12)"
  }

  $dashboardDir = Split-Path -Parent $found[0]
  $Root = Split-Path -Parent $dashboardDir
} else {
  if ([string]::IsNullOrWhiteSpace($Root)) {
    throw 'ค่า -Root ว่างเปล่า; แนะนำให้รันด้วย -Root <path> (โฟลเดอร์แม่ที่มี bn88-frontend-dashboard-v12)'
  }
  if (-not (Test-Path $Root)) {
    throw "ไม่พบ path ของ -Root: $Root; แนะนำให้หา root โดยตรวจให้มีโฟลเดอร์ bn88-frontend-dashboard-v12 แล้วรัน -Root <path>"
  }
  $dashboardDir = Join-Path $Root 'bn88-frontend-dashboard-v12'
}

if ([string]::IsNullOrWhiteSpace($Root)) {
  throw 'Root ว่างเปล่า; แนะนำให้รันด้วย -Root <path>'
}

if ([string]::IsNullOrWhiteSpace($dashboardDir)) {
  throw "ไม่พบ dashboardDir; ค้นแล้ว: $($searchedNotes -join '; '). แนะนำให้รันด้วย -Root <path>"
}

$packageJson = Join-Path $dashboardDir 'package.json'

Write-Host "PSScriptRoot: $PSScriptRoot"
Write-Host "ROOT: $Root"
Write-Host "PWD: $(Get-Location)"
Write-Host "dashboard path: $dashboardDir"
Write-Host "Test-Path package.json: $(Test-Path $packageJson)"

if (-not (Test-Path $dashboardDir)) {
  throw "ไม่พบโฟลเดอร์ dashboard: $dashboardDir (ค้นแล้ว: $($searchedNotes -join '; ')). แนะนำให้รันด้วย -Root <path>"
}

if (-not (Test-Path $packageJson)) {
  throw "ไม่พบ package.json ที่: $packageJson (ค้นแล้ว: $($searchedNotes -join '; ')). แนะนำให้รันด้วย -Root <path>"
}

Set-Location $Root
Set-Location 'bn88-frontend-dashboard-v12'
Write-Host "PWD(now): $(Get-Location)"

npm ci
if ($LASTEXITCODE -ne 0) {
  throw 'npm ci failed'
}

npm run dev
if ($LASTEXITCODE -ne 0) {
  throw 'npm run dev failed'
}
