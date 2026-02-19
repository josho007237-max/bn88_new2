param(
  [string]$Root = 'C:\Go23_th',
  [string]$ExpectedWorkDir = 'C:\Go23_th\bn88_new2\-bn88-new-clean-main'
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

Write-Host "[cleanup-audit] READ-ONLY mode (no delete action)" -ForegroundColor Cyan
Write-Host "Root: $Root"
Write-Host "Expected working directory: $ExpectedWorkDir"
Write-Host "Expected exists: $([bool](Test-Path -LiteralPath $ExpectedWorkDir))"

if (-not (Test-Path -LiteralPath $Root)) {
  Write-Host "Root not found: $Root" -ForegroundColor Red
  exit 1
}

$targetNames = @(
  'bn88_new2',
  '-bn88-new-clean-main',
  '-bn88-new-clean',
  'bn88-backend-v12',
  'bn88-frontend-dashboard-v12'
)

$dirs = Get-ChildItem -LiteralPath $Root -Directory -Force -ErrorAction SilentlyContinue
$report = foreach ($d in $dirs) {
  $bytes = Get-FolderSizeBytes -Path $d.FullName
  $hasGit = Test-Path -LiteralPath (Join-Path $d.FullName '.git')
  $hasBackend = Test-Path -LiteralPath (Join-Path $d.FullName 'bn88-backend-v12')
  $hasFrontend = Test-Path -LiteralPath (Join-Path $d.FullName 'bn88-frontend-dashboard-v12')
  [pscustomobject]@{
    Name = $d.Name
    FullPath = $d.FullName
    Size = Format-Size -Bytes $bytes
    HasGit = $hasGit
    HasBackendDir = $hasBackend
    HasFrontendDir = $hasFrontend
  }
}

Write-Host "`n== Top-level folders under root ==" -ForegroundColor Yellow
$report | Sort-Object Name | Format-Table -AutoSize Name, Size, HasGit, HasBackendDir, HasFrontendDir

Write-Host "`n== Duplicate/candidate folders to review ==" -ForegroundColor Yellow
$hits = $report | Where-Object { $targetNames -contains $_.Name }
if (-not $hits) {
  Write-Host "No exact-name candidates found under $Root"
} else {
  $hits | Sort-Object Name | Format-Table -AutoSize Name, FullPath, Size, HasGit, HasBackendDir, HasFrontendDir
}

Write-Host "`n== Safe cleanup checklist (manual) ==" -ForegroundColor Yellow
Write-Host "1) Keep only: $ExpectedWorkDir"
Write-Host "2) For duplicate folders, move to Recycle Bin first (do NOT permanently delete immediately)."
Write-Host "3) Re-open terminal at kept repo and run: git status"
Write-Host "4) Verify backend path exists: Test-Path '$ExpectedWorkDir\\bn88-backend-v12'"
Write-Host "5) Verify frontend path exists: Test-Path '$ExpectedWorkDir\\bn88-frontend-dashboard-v12'"

Write-Host "`n[cleanup-audit] done" -ForegroundColor Green
