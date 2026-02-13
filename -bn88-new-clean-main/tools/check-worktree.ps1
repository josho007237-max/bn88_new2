param(
  [ValidateSet('delete','commit','ignore')]
  [string]$Mode
)

$ErrorActionPreference = "Stop"

Write-Host "== git status -sb =="
git status -sb

# Detect untracked tools/ folder
$status = git status --porcelain
$hasUntrackedTools = $false
foreach ($line in $status) {
  if ($line -match '^\?\?\s+tools\/') {
    $hasUntrackedTools = $true
    break
  }
}

if ($hasUntrackedTools) {
  if (-not $Mode) {
    Write-Host "Untracked tools/ detected. Provide -Mode (delete | commit | ignore)."
  } elseif ($Mode -eq 'delete') {
    Remove-Item -Recurse -Force tools
    Write-Host "Deleted tools/"
    git status -sb
  } elseif ($Mode -eq 'commit') {
    git add tools
    git commit -m "chore: add tools scripts"
  } elseif ($Mode -eq 'ignore') {
    if (-not (Test-Path -Path .gitignore)) {
      New-Item -ItemType File -Path .gitignore | Out-Null
    }
    $gitignore = Get-Content .gitignore -ErrorAction SilentlyContinue
    if ($gitignore -notcontains 'tools/') {
      Add-Content -Path .gitignore -Value 'tools/'
    }
    git add .gitignore
    git commit -m "chore: ignore tools folder"
  }
}

Write-Host "`n== Summary =="
$dirty = (git status --porcelain).Length -gt 0
if ($dirty) {
  Write-Host "DIRTY"
} else {
  Write-Host "CLEAN"
}
