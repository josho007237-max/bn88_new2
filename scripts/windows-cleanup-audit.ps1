param(
  [string]$Root = 'C:\Go23_th',
  [string]$ExpectedWorkDir = 'C:\Go23_th\bn88_new2\-bn88-new-clean-main',
  [switch]$MoveToTrash,
  [string]$TrashDir = 'C:\Go23_th\_TRASH',
  [string[]]$CandidateNames = @('bn88_new2', '-bn88-new-clean-main', '-bn88-new-clean', 'bn88-backend-v12', 'bn88-frontend-dashboard-v12')
)

$ErrorActionPreference = 'Stop'

function Get-FolderSizeBytes {
  param([string]$Path)
  try {
    return (Get-ChildItem -LiteralPath $Path -Force -Recurse -File -ErrorAction SilentlyContinue |
      Measure-Object -Property Length -Sum).Sum
  } catch {
    return 0
  }
}

function Format-Size {
  param([double]$Bytes)
  if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
  if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
  if ($Bytes -ge 1KB) { return ('{0:N2} KB' -f ($Bytes / 1KB)) }
  return ('{0} B' -f [int64]$Bytes)
}

Write-Host "[cleanup-audit] mode: $($(if($MoveToTrash){'MOVE-TO-TRASH'}else{'READ-ONLY'}))" -ForegroundColor Cyan
Write-Host "Root: $Root"
Write-Host "Expected working directory: $ExpectedWorkDir"
Write-Host "Expected exists: $([bool](Test-Path -LiteralPath $ExpectedWorkDir))"

if (-not (Test-Path -LiteralPath $Root)) {
  Write-Host "Root not found: $Root" -ForegroundColor Red
  exit 1
}

$dirs = Get-ChildItem -LiteralPath $Root -Directory -Force -ErrorAction SilentlyContinue
$report = foreach ($d in $dirs) {
  $bytes = Get-FolderSizeBytes -Path $d.FullName
  $hasGit = Test-Path -LiteralPath (Join-Path $d.FullName '.git')
  $hasPackageJson = Test-Path -LiteralPath (Join-Path $d.FullName 'package.json')
  $hasBackend = Test-Path -LiteralPath (Join-Path $d.FullName 'bn88-backend-v12')
  $hasFrontend = Test-Path -LiteralPath (Join-Path $d.FullName 'bn88-frontend-dashboard-v12')
  [pscustomobject]@{
    Name = $d.Name
    FullPath = $d.FullName
    Size = Format-Size -Bytes $bytes
    LastWriteTime = $d.LastWriteTime
    HasGit = $hasGit
    HasPackageJson = $hasPackageJson
    HasBackendDir = $hasBackend
    HasFrontendDir = $hasFrontend
  }
}

Write-Host "`n== Top-level folders under root ==" -ForegroundColor Yellow
$report | Sort-Object Name | Format-Table -AutoSize Name, Size, LastWriteTime, HasGit, HasPackageJson, HasBackendDir, HasFrontendDir

Write-Host "`n== Duplicate/candidate folders to review ==" -ForegroundColor Yellow
$hits = $report | Where-Object { $CandidateNames -contains $_.Name }
if (-not $hits) {
  Write-Host "No exact-name candidates found under $Root"
} else {
  $hits | Sort-Object Name | Format-Table -AutoSize Name, FullPath, Size, LastWriteTime, HasGit, HasPackageJson, HasBackendDir, HasFrontendDir
}

if ($MoveToTrash) {
  if (-not (Test-Path -LiteralPath $TrashDir)) {
    New-Item -ItemType Directory -Path $TrashDir -Force | Out-Null
  }

  $keepFullPath = ''
  if (Test-Path -LiteralPath $ExpectedWorkDir) {
    $keepFullPath = (Resolve-Path -LiteralPath $ExpectedWorkDir).Path
  }

  Write-Host "`n== Move to trash actions ==" -ForegroundColor Yellow
  foreach ($item in $hits) {
    $source = $item.FullPath
    if ($keepFullPath -and $source -eq $keepFullPath) {
      Write-Host "Skip keep path: $source"
      continue
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $dest = Join-Path $TrashDir ("{0}_{1}" -f $item.Name, $timestamp)
    Write-Host "Move: $source"
    Write-Host "  -> $dest"
    Move-Item -LiteralPath $source -Destination $dest -Force
  }
}

Write-Host "`n== Safe cleanup checklist ==" -ForegroundColor Yellow
Write-Host "1) Keep only: $ExpectedWorkDir"
Write-Host "2) Review candidate folders table before moving"
Write-Host "3) Prefer -MoveToTrash to move into $TrashDir (no permanent delete)"
Write-Host "4) Re-open terminal at kept repo and run: git status"
Write-Host "5) Verify backend/frontend paths still exist under kept repo"

Write-Host "`n[cleanup-audit] done" -ForegroundColor Green
