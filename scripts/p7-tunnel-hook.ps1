$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot '-bn88-new-clean-main\cloudflared\bn88-api.yml'
$cloudflaredDir = Join-Path $env:USERPROFILE '.cloudflared'
$credentialsByName = Join-Path $cloudflaredDir 'bn88-api.json'
$credentialsAny = Get-ChildItem -LiteralPath $cloudflaredDir -Filter '*.json' -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -notin @('cert.json', 'cert.pem') } |
  Select-Object -First 1

if (-not (Test-Path -LiteralPath $configPath)) {
  Write-Host "[p7-tunnel-hook] missing config: $configPath" -ForegroundColor Yellow
  exit 1
}

$portOk = Test-NetConnection -ComputerName '127.0.0.1' -Port 3000 -InformationLevel Quiet
if (-not $portOk) {
  Write-Host '[p7-tunnel-hook] backend port 3000 is not listening' -ForegroundColor Yellow
  Write-Host '[p7-tunnel-hook] start backend first (npm run dev in bn88-backend-v12)' -ForegroundColor Yellow
  exit 1
}

if (Test-Path -LiteralPath $credentialsByName) {
  $credentialsPath = $credentialsByName
} elseif ($credentialsAny) {
  $credentialsPath = $credentialsAny.FullName
} else {
  Write-Host "[p7-tunnel-hook] tunnel credentials not found under $cloudflaredDir" -ForegroundColor Yellow
  Write-Host '[p7-tunnel-hook] run: cloudflared tunnel login' -ForegroundColor Yellow
  Write-Host '[p7-tunnel-hook] and ensure tunnel bn88-api exists' -ForegroundColor Yellow
  exit 1
}

Write-Host "[p7-tunnel-hook] config: $configPath"
Write-Host "[p7-tunnel-hook] credentials: $credentialsPath"
Write-Host '[p7-tunnel-hook] health test command:' -ForegroundColor Cyan
Write-Host 'curl.exe -i https://hook.bn9.app/api/health' -ForegroundColor Cyan
Write-Host ''
Write-Host '[p7-tunnel-hook] starting cloudflared tunnel bn88-api...'
cloudflared tunnel --config "$configPath" run bn88-api
