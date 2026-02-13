$ErrorActionPreference = "Stop"

$repoPath = "C:\BN88\BN88-new-clean"
if (Test-Path -Path $repoPath) {
  Set-Location -Path $repoPath
}

try {
  $root = (git rev-parse --show-toplevel).Trim()
  Write-Host "Repo Root: $root"
  $head = (git rev-parse HEAD).Trim()
  $originMain = (git rev-parse origin/main).Trim()
  Write-Host "HEAD: $head"
  Write-Host "origin/main: $originMain"
} catch {
  Write-Host "Repo not found. Please check path: C:\BN88\BN88-new-clean"
}
