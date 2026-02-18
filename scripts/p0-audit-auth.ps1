param(
  [Parameter(Mandatory=$true)]
  [string]$BackendPath
)

$bp = (Resolve-Path $BackendPath).Path
$src = Join-Path $bp "src"

Write-Host ("[p0-audit-auth] backend = {0}" -f $bp)
if (-not (Test-Path $src)) {
  Write-Host ("[p0-audit-auth] ERROR: src not found at {0}" -f $src) -ForegroundColor Red
  exit 1
}

$rg = Get-Command rg -ErrorAction SilentlyContinue
if (-not $rg) {
  Write-Host "[p0-audit-auth] ERROR: rg not found in PATH" -ForegroundColor Red
  Write-Host "Install ripgrep or add rg to PATH, then re-run." -ForegroundColor Yellow
  exit 1
}

function SummarizeMatches([string]$title, [string[]]$lines) {
  if (-not $lines -or $lines.Count -eq 0) {
    Write-Host ("[{0}] 0 matches" -f $title) -ForegroundColor Yellow
    return
  }

  # Extract "file:line" (rg output is: file:line:content)
  $locs = $lines | ForEach-Object {
    $parts = $_ -split ":", 3
    if ($parts.Count -ge 2) { "{0}:{1}" -f $parts[0], $parts[1] } else { $_ }
  }

  $files = $lines | ForEach-Object { ($_ -split ":", 2)[0] } | Select-Object -Unique
  Write-Host ("[{0}] matches={1}, files={2}" -f $title, $lines.Count, $files.Count) -ForegroundColor Green

  # show up to 25 locations
  $locs | Select-Object -First 25 | ForEach-Object { Write-Host (" - {0}" -f $_) }
  if ($locs.Count -gt 25) { Write-Host (" ... (+{0} more)" -f ($locs.Count-25)) }
}

Write-Host "`n# Scan (literal -F) under src`n" -ForegroundColor Cyan

$guard = rg -n -S -F "authGuard(" $src 2>$null
$perm  = rg -n -S -F "requirePermission(" $src 2>$null

SummarizeMatches "authGuard(" $guard
Write-Host ""
SummarizeMatches "requirePermission(" $perm

Write-Host "`n[p0-audit-auth] DONE" -ForegroundColor Cyan
