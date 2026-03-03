param(
  [string]$BotId = 'dev-bot',
  [string]$Tenant = 'bn9',
  [string]$ApiBase = 'http://127.0.0.1:3000',
  [Parameter(Mandatory = $true)][string]$ChannelSecret,
  [Parameter(Mandatory = $true)][string]$ChannelAccessToken
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$backend = Join-Path $root 'bn88-backend-v12'

if (-not (Test-Path $backend)) {
  Write-Error "Backend path not found: $backend"
}

Push-Location $backend
try {
  $env:BOT_ID = $BotId
  $env:TENANT = $Tenant
  $env:API_BASE_URL = $ApiBase
  $env:LINE_CHANNEL_SECRET = $ChannelSecret
  $env:LINE_CHANNEL_ACCESS_TOKEN = $ChannelAccessToken

  npm run dev:seed:line
} finally {
  Pop-Location
}
