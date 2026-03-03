param(
  [string]$Root
)

$ErrorActionPreference = 'Stop'

$searchOrder = @('C:\Go23_th', 'C:\BN88', 'C:\Users\ADMIN')
$searchedNotes = @()

if ([string]::IsNullOrWhiteSpace($Root)) {
  Write-Host "Searching roots: $($searchOrder -join ', ')"

  $found = @()
  foreach ($base in $searchOrder) {
    if (-not (Test-Path $base)) {
      $searchedNotes += "$base (missing)"
      continue
    }

    $searchedNotes += "$base (Get-ChildItem depth=6)"
    $matches = @(Get-ChildItem -Path $base -Directory -Recurse -Depth 6 -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -eq 'bn88-frontend-dashboard-v12' } |
      Select-Object -ExpandProperty FullName)

    if ($matches.Count -gt 0) {
      $found += $matches
    }
  }

  if ($found.Count -eq 0) {
    foreach ($base in $searchOrder) {
      if (-not (Test-Path $base)) { continue }

      $searchedNotes += "$base (where.exe /r package.json + findstr)"
      $whereResults = @(where.exe /r $base package.json 2>$null)
      if ($whereResults.Count -eq 0) { continue }

      $filtered = @($whereResults | findstr /R /I "bn88-frontend-dashboard-v12\\package.json$")
      foreach ($line in $filtered) {
        $pkgPath = "$line".Trim()
        if (-not [string]::IsNullOrWhiteSpace($pkgPath)) {
          $dir = Split-Path -Parent $pkgPath
          if (Test-Path $dir) {
            $found += $dir
          }
        }
      }
    }
  }

  $found = @($found | Select-Object -Unique)
  if ($found.Count -gt 0) {
    Write-Host 'Found dashboard candidates:'
    $found | ForEach-Object { Write-Host "  - $_" }
  }

  if ($found.Count -eq 0) {
    throw "ไม่พบโฟลเดอร์ bn88-frontend-dashboard-v12 หรือ package.json ที่เกี่ยวข้อง; ค้นแล้ว: $($searchedNotes -join '; '). แนะนำให้รันด้วย -Root <path>"
  }

  $dashboardDir = $found[0]
  $Root = Split-Path -Parent $dashboardDir
} else {
  $dashboardDir = Join-Path $Root 'bn88-frontend-dashboard-v12'
}

if ([string]::IsNullOrWhiteSpace($Root)) {
  throw 'Root ว่างเปล่า; แนะนำให้รันด้วย -Root <path>'
}

if ([string]::IsNullOrWhiteSpace($dashboardDir)) {
  throw "ไม่พบ dashboardDir; ค้นแล้ว: $($searchedNotes -join '; '). แนะนำให้รันด้วย -Root <path>"
}

$packageJson = Join-Path $dashboardDir 'package.json'

Write-Host "ROOT: $Root"
Write-Host "PWD(before): $(Get-Location)"
Write-Host "Test-Path package.json: $(Test-Path $packageJson)"

if (-not (Test-Path $dashboardDir)) {
  throw "ไม่พบโฟลเดอร์ dashboard: $dashboardDir (ค้นแล้ว: $($searchedNotes -join '; ')). แนะนำให้รันด้วย -Root <path>"
}

if (-not (Test-Path $packageJson)) {
  throw "ไม่พบ package.json ที่: $packageJson (ค้นแล้ว: $($searchedNotes -join '; ')). แนะนำให้รันด้วย -Root <path>"
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
