param(
  [string]$Domain = "api.bn9.app",
  [string]$TunnelName = "bn88-api",
  [string]$LocalHealthUrl = "http://127.0.0.1:3000/api/health"
)

$scriptPath = Join-Path $PSScriptRoot "bn88-backend-v12/src/scripts/smoke-domain.ps1"
if (-not (Test-Path $scriptPath)) {
  throw "smoke-domain script not found: $scriptPath"
}

pwsh -File $scriptPath -Domain $Domain -TunnelName $TunnelName -LocalHealthUrl $LocalHealthUrl
exit $LASTEXITCODE
