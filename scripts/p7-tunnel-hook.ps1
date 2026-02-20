$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot '-bn88-new-clean-main\cloudflared\config-bn88-api.yml'
$cloudflaredDir = Join-Path $env:USERPROFILE '.cloudflared'

$portOk = Test-NetConnection -ComputerName '127.0.0.1' -Port 3000 -InformationLevel Quiet
if (-not $portOk) {
  Write-Host '[p7-tunnel-hook] backend port 3000 is not listening' -ForegroundColor Yellow
  Write-Host '[p7-tunnel-hook] start backend first (npm run dev in bn88-backend-v12)' -ForegroundColor Yellow
  exit 1
}

$tunnelLine = cloudflared tunnel list 2>$null |
  Select-String -Pattern '^\s*[0-9a-fA-F-]{36}\s+bn88-api\b' |
  Select-Object -First 1

if (-not $tunnelLine) {
  Write-Host '[p7-tunnel-hook] tunnel bn88-api not found from cloudflared tunnel list' -ForegroundColor Yellow
  exit 1
}

$uuid = ([regex]::Match($tunnelLine.Line, '[0-9a-fA-F-]{36}')).Value
if ([string]::IsNullOrWhiteSpace($uuid)) {
  Write-Host '[p7-tunnel-hook] cannot parse UUID for tunnel bn88-api' -ForegroundColor Yellow
  exit 1
}

$credentialsPath = Join-Path $cloudflaredDir "$uuid.json"
if (-not (Test-Path -LiteralPath $credentialsPath)) {
  Write-Host "[p7-tunnel-hook] missing credentials: $credentialsPath" -ForegroundColor Yellow
  Write-Host '[p7-tunnel-hook] copy tunnel token/credentials from Cloudflare Zero Trust first' -ForegroundColor Yellow
  exit 1
}

$configDir = Split-Path -Parent $configPath
New-Item -ItemType Directory -Force -Path $configDir | Out-Null

$configYaml = @"
tunnel: $uuid
credentials-file: $credentialsPath

ingress:
  - hostname: hook.bn9.app
    service: http://127.0.0.1:3000
  - hostname: api.bn9.app
    service: http://127.0.0.1:3000
  - service: http_status:404
"@

Set-Content -LiteralPath $configPath -Value $configYaml -Encoding utf8

Write-Host "[p7-tunnel-hook] tunnel uuid: $uuid"
Write-Host "[p7-tunnel-hook] wrote config: $configPath"
Write-Host '[p7-tunnel-hook] health test command:' -ForegroundColor Cyan
Write-Host 'curl.exe --ssl-no-revoke -i https://hook.bn9.app/api/health' -ForegroundColor Cyan
Write-Host ''
Write-Host '[p7-tunnel-hook] starting cloudflared tunnel...'
cloudflared tunnel --config "$configPath" run $uuid
