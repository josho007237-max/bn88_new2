param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot/..").Path
)

$ErrorActionPreference = 'Stop'

Write-Host "[p0-audit] repo: $RepoRoot"

$server = Join-Path $RepoRoot 'src/server.ts'
$authMw = Join-Path $RepoRoot 'src/mw/auth.ts'
$authGuardAlias = Join-Path $RepoRoot 'src/middleware/authGuard.ts'
$basicAuth = Join-Path $RepoRoot 'src/middleware/basicAuth.ts'
$adminBots = Join-Path $RepoRoot 'src/routes/admin/bots.ts'
$statusDoc = Join-Path $RepoRoot 'WORKPLAN_STATUS.md'

foreach ($f in @($server,$authMw,$authGuardAlias,$basicAuth,$adminBots,$statusDoc)) {
  if (-not (Test-Path $f)) {
    throw "missing file: $f"
  }
}

Write-Host "`n== server mounts: admin + webhooks =="
Select-String -Path $server -Pattern '/api/webhooks|/api/admin' |
  ForEach-Object { "{0}:{1}: {2}" -f $_.Path.Replace($RepoRoot + '\\',''), $_.LineNumber, $_.Line.Trim() }

Write-Host "`n== auth chain for /api/admin/bots =="
Select-String -Path $server -Pattern '/api/admin/bots' |
  ForEach-Object { "{0}:{1}: {2}" -f $_.Path.Replace($RepoRoot + '\\',''), $_.LineNumber, $_.Line.Trim() }
Select-String -Path $adminBots -Pattern 'requirePermission\(\["manageBots"\]\)' |
  ForEach-Object { "{0}:{1}: {2}" -f $_.Path.Replace($RepoRoot + '\\',''), $_.LineNumber, $_.Line.Trim() }

Write-Host "`n== auth middleware files =="
Select-String -Path $authGuardAlias -Pattern 'export \{ authGuard' |
  ForEach-Object { "{0}:{1}: {2}" -f $_.Path.Replace($RepoRoot + '\\',''), $_.LineNumber, $_.Line.Trim() }
Select-String -Path $authMw -Pattern 'export function authGuard' |
  ForEach-Object { "{0}:{1}: {2}" -f $_.Path.Replace($RepoRoot + '\\',''), $_.LineNumber, $_.Line.Trim() }
Select-String -Path $basicAuth -Pattern 'export function requirePermission|permissionsFromClaims' |
  ForEach-Object { "{0}:{1}: {2}" -f $_.Path.Replace($RepoRoot + '\\',''), $_.LineNumber, $_.Line.Trim() }

Write-Host "`n== workplan status =="
Get-Content -Path $statusDoc -TotalCount 40

Write-Host "`n[p0-audit] done"
