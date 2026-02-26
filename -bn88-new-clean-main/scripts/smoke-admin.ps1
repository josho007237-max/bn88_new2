param(
  [string]$BaseUrl = 'http://127.0.0.1:3000',
  [string]$Tenant = 'bn9',
  [string]$Email = 'root@bn9.local',
  [string]$Password = 'bn9@12345'
)

$ErrorActionPreference = 'Stop'
$failed = $false

function Step([string]$Name, [scriptblock]$Action) {
  try {
    & $Action
    Write-Host "[PASS] $Name" -ForegroundColor Green
  } catch {
    $script:failed = $true
    Write-Host "[FAIL] $Name :: $($_.Exception.Message)" -ForegroundColor Red
  }
}

$token = $null
$headers = $null
$botId = $null

Step 'GET /api/health' {
  $health = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/health"
  if ($null -eq $health) { throw 'health response is null' }
}

Step 'POST /api/admin/auth/login' {
  $body = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress
  $login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/admin/auth/login" -ContentType 'application/json' -Body $body
  $script:token = $login.token
  if ([string]::IsNullOrWhiteSpace($script:token)) { throw 'token missing from login response' }
  $script:headers = @{ Authorization = "Bearer $script:token"; 'x-tenant' = $Tenant }
}

Step 'GET /api/admin/bots' {
  if ($null -eq $script:headers) { throw 'missing auth headers' }
  $bots = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/bots" -Headers $script:headers
  if ($bots.ok -ne $true) { throw "bots.ok expected true, got '$($bots.ok)'" }
  if (-not $bots.items -or $bots.items.Count -lt 1) { throw 'bots list is empty' }
  $script:botId = $bots.items[0].id
  if ([string]::IsNullOrWhiteSpace($script:botId)) { throw 'first bot id is empty' }
}

Step 'GET /api/admin/bots/:id/secrets' {
  if ([string]::IsNullOrWhiteSpace($script:botId)) { throw 'missing bot id' }
  $secrets = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/bots/$script:botId/secrets" -Headers $script:headers
  if ($secrets.ok -ne $true) { throw "secrets.ok expected true, got '$($secrets.ok)'" }
}

if ($failed) {
  Write-Host '[smoke-admin] RESULT: FAIL' -ForegroundColor Red
  exit 1
}

Write-Host '[smoke-admin] RESULT: PASS' -ForegroundColor Green
exit 0
