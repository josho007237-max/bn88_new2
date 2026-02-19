$ErrorActionPreference = "Stop"

$root = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$backendPath = Join-Path $root "bn88-backend-v12"
$dashboardPath = Join-Path $root "bn88-frontend-dashboard-v12"
$logsPath = Join-Path $root "logs"

$tunnelConfig = Join-Path $env:USERPROFILE ".cloudflared\config-bn88.yml"
$tunnelId = "e416a082-3967-4708-a1da-f0a86c18a8ac"
$domain = "api.bn9.app"

function Set-Or-AddEnvValue {
  param(
    [string]$Path,
    [string]$Key,
    [string]$Value
  )

  $lines = @()
  if (Test-Path $Path) {
    $lines = Get-Content -Path $Path
  }

  $pattern = "^$([regex]::Escape($Key))="
  $matched = $false
  $newLines = @()

  foreach ($line in $lines) {
    if ($line -match $pattern) {
      $newLines += "$Key=$Value"
      $matched = $true
    } else {
      $newLines += $line
    }
  }

  if (-not $matched) {
    $newLines += "$Key=$Value"
  }

  Set-Content -Path $Path -Value $newLines -Encoding UTF8
}

if (-not (Test-Path $backendPath)) { throw "Backend path not found: $backendPath" }
if (-not (Test-Path $dashboardPath)) { throw "Dashboard path not found: $dashboardPath" }

New-Item -ItemType Directory -Force -Path $logsPath | Out-Null

Write-Host "Starting backend..." -ForegroundColor Cyan
$backendProc = Start-Process -FilePath "npm.cmd" -ArgumentList @("run", "dev") -WorkingDirectory $backendPath -RedirectStandardOutput (Join-Path $logsPath "backend.out.log") -RedirectStandardError (Join-Path $logsPath "backend.err.log") -PassThru
Write-Host "  backend PID=$($backendProc.Id)" -ForegroundColor DarkGray

Write-Host "Starting cloudflared tunnel..." -ForegroundColor Cyan
$tunnelProc = Start-Process -FilePath "cloudflared" -ArgumentList @("--config", $tunnelConfig, "--loglevel", "debug", "tunnel", "run", $tunnelId) -WorkingDirectory $root -RedirectStandardOutput (Join-Path $logsPath "tunnel.out.log") -RedirectStandardError (Join-Path $logsPath "tunnel.err.log") -PassThru
Write-Host "  tunnel PID=$($tunnelProc.Id)" -ForegroundColor DarkGray

Write-Host "Preparing dashboard env..." -ForegroundColor Cyan
$dashboardEnvLocal = Join-Path $dashboardPath ".env.local"
Set-Or-AddEnvValue -Path $dashboardEnvLocal -Key "VITE_API_BASE" -Value "https://api.bn9.app/api"
Set-Or-AddEnvValue -Path $dashboardEnvLocal -Key "VITE_TENANT" -Value "bn9"

Write-Host "Starting dashboard..." -ForegroundColor Cyan
$dashboardProc = Start-Process -FilePath "npm.cmd" -ArgumentList @("run", "dev") -WorkingDirectory $dashboardPath -RedirectStandardOutput (Join-Path $logsPath "dashboard.out.log") -RedirectStandardError (Join-Path $logsPath "dashboard.err.log") -PassThru
Write-Host "  dashboard PID=$($dashboardProc.Id)" -ForegroundColor DarkGray

Start-Sleep -Seconds 5

$dashboardUrl = "http://localhost:5555"
$dashboardOutLog = Join-Path $logsPath "dashboard.out.log"
if (Test-Path $dashboardOutLog) {
  $viteLine = Get-Content -Path $dashboardOutLog | Where-Object { $_ -match "https?://localhost:\d+" } | Select-Object -Last 1
  if ($viteLine) {
    $match = [regex]::Match($viteLine, "https?://localhost:\d+")
    if ($match.Success) { $dashboardUrl = $match.Value }
  }
}

Write-Host "" 
Write-Host "Running smoke-domain check..." -ForegroundColor Cyan
$smokeScript = Join-Path $backendPath "src\scripts\smoke-domain.ps1"
& $smokeScript -Domain $domain -TunnelName $tunnelId -LocalHealthUrl "http://127.0.0.1:3000/api/health"
$smokeExit = $LASTEXITCODE

Write-Host ""
Write-Host "Open URLs:" -ForegroundColor Green
Write-Host "  https://api.bn9.app/api/health" -ForegroundColor Yellow
Write-Host "  $dashboardUrl" -ForegroundColor Yellow
Write-Host ""
Write-Host "Logs:" -ForegroundColor Green
Write-Host "  $logsPath\\backend.out.log"
Write-Host "  $logsPath\\backend.err.log"
Write-Host "  $logsPath\\tunnel.out.log"
Write-Host "  $logsPath\\tunnel.err.log"
Write-Host "  $logsPath\\dashboard.out.log"
Write-Host "  $logsPath\\dashboard.err.log"

if ($smokeExit -ne 0) {
  exit 1
}

exit 0
