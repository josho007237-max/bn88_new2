param(
  [string]$PublicBase = 'https://api.bn9.app',
  [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = 'Stop'

$script:Failures = @()

function Add-Result {
  param(
    [bool]$Ok,
    [string]$Step,
    [string]$Detail
  )

  if ($Ok) {
    Write-Host "[PASS][$Step] $Detail" -ForegroundColor Green
    return
  }

  Write-Host "[FAIL][$Step] $Detail" -ForegroundColor Red
  $script:Failures += $Step
}

function Test-ListeningPort {
  param([int]$Port)

  $tcp = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
  return [bool]$tcp
}

function Resolve-WebhookPath {
  param([string]$Root)

  $serverFile = Join-Path $Root 'bn88-backend-v12/src/server.ts'
  if (-not (Test-Path $serverFile)) {
    return '/api/webhooks/line?tenant=<tenant>&botId=<botId>'
  }

  $raw = Get-Content -Raw -Path $serverFile
  if ($raw -match 'app\.use\("(?<path>/api/webhooks/line)"') {
    return "$($matches.path)?tenant=<tenant>&botId=<botId>"
  }

  return '/api/webhooks/line?tenant=<tenant>&botId=<botId>'
}

Write-Host '=== LINE E2E CHECK ===' -ForegroundColor Cyan
Write-Host "RepoRoot: $RepoRoot" -ForegroundColor DarkGray

$port3000 = Test-ListeningPort -Port 3000
Add-Result -Ok $port3000 -Step 'PORT' -Detail 'Local port 3000 (backend) is listening'

$port6380 = Test-ListeningPort -Port 6380
Add-Result -Ok $port6380 -Step 'PORT' -Detail 'Local port 6380 (redis) is listening'

$publicHealthUrl = ('{0}/api/health' -f $PublicBase.TrimEnd('/'))
try {
  $health = Invoke-WebRequest -Uri $publicHealthUrl -Method Get -UseBasicParsing -TimeoutSec 15
  Add-Result -Ok ($health.StatusCode -eq 200) -Step 'PUBLIC_HEALTH' -Detail "GET $publicHealthUrl => $($health.StatusCode)"
} catch {
  Add-Result -Ok $false -Step 'PUBLIC_HEALTH' -Detail "GET $publicHealthUrl failed: $($_.Exception.Message)"
}

$webhookPath = Resolve-WebhookPath -Root $RepoRoot
Write-Host "Webhook path (set in LINE Messaging API): $webhookPath" -ForegroundColor Yellow
Write-Host "Suggested full URL: $($PublicBase.TrimEnd('/'))$webhookPath" -ForegroundColor Yellow
Write-Host 'Inbound log quick check:' -ForegroundColor Cyan
Write-Host '  1) Run backend with tee: npm run dev *>&1 | Tee-Object -FilePath .\logs\backend-dev.log' -ForegroundColor Gray
Write-Host '  2) Follow inbound logs: Get-Content .\logs\backend-dev.log -Wait | Select-String "LINE webhook|invalid_signature|LINE verify"' -ForegroundColor Gray

if ($script:Failures.Count -gt 0) {
  $uniq = ($script:Failures | Select-Object -Unique) -join ', '
  Write-Host "[SUMMARY] LINE E2E CHECK = FAIL (steps: $uniq)" -ForegroundColor Red
  exit 1
}

Write-Host '[SUMMARY] LINE E2E CHECK = PASS' -ForegroundColor Green
