param(
  [string]$BaseUrl = 'http://127.0.0.1:3000',
  [string]$Email = 'root@bn9.local',
  [string]$Password = 'bn9@12345',
  [string]$Tenant = 'bn9',
  [string]$LineContentId = ''
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  Write-Host "[smoke-all] ERROR: $Message" -ForegroundColor Red
  exit 1
}

Write-Host "[smoke-all] health => $BaseUrl/api/health"
$health = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/health"
if ($null -eq $health) { Fail 'health response is null' }
if ($health.ok -ne $true) { Fail "health.ok expected true, got '$($health.ok)'" }
if ($health.adminApi -ne $true) { Fail "health.adminApi expected true, got '$($health.adminApi)'" }

Write-Host "[smoke-all] login => $BaseUrl/api/admin/auth/login"
$loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress
$login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/admin/auth/login" -ContentType 'application/json' -Body $loginBody
$token = $login.token
if ([string]::IsNullOrWhiteSpace($token)) { Fail 'login did not return token' }

Write-Host "[smoke-all] bots => $BaseUrl/api/admin/bots"
$headers = @{ Authorization = "Bearer $token"; 'x-tenant' = $Tenant }
$bots = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/bots" -Headers $headers
if ($null -eq $bots) { Fail 'bots response is null' }
if ($null -eq $bots.items) { Fail 'bots.items missing in response' }
if ($bots.items.Count -le 0) { Fail "bots.items expected length > 0, got $($bots.items.Count)" }

Write-Host "[smoke-all] SSE => $BaseUrl/api/live/$Tenant?token=<token> (curl -i -N, max-time 5s)"
$curlCmd = if (Get-Command curl.exe -ErrorAction SilentlyContinue) { 'curl.exe' } elseif (Get-Command curl -ErrorAction SilentlyContinue) { 'curl' } else { $null }
if (-not $curlCmd) {
  Fail 'curl not found, cannot run SSE/line-content smoke checks'
}

$sseUrl = "$BaseUrl/api/live/$Tenant?token=$token"
$sseOutput = & $curlCmd -i -N --max-time 5 $sseUrl 2>&1
$sseText = ($sseOutput | Out-String)
if ($sseText -notmatch 'HTTP/\S+\s+200') {
  Fail "SSE expected HTTP 200, got: $($sseText -split "`n" | Select-Object -First 1)"
}
if ($sseText -notmatch '(?i)content-type:\s*text/event-stream') {
  Fail 'SSE missing Content-Type: text/event-stream'
}
Write-Host '[smoke-all] SSE probe returned HTTP 200 + text/event-stream' -ForegroundColor Green

Write-Host "[smoke-all] line-content(FAKE_ID, Authorization header) => $BaseUrl/api/admin/chat/line-content/FAKE_ID"
$lineOutput = & $curlCmd -i -sS -X GET "$BaseUrl/api/admin/chat/line-content/FAKE_ID" -H "Authorization: Bearer $token" -H "x-tenant: $Tenant" 2>&1
$lineText = ($lineOutput | Out-String)
if ($lineText -match 'HTTP/\S+\s+401' -or $lineText -match 'HTTP/\S+\s+403') {
  Fail 'line-content FAKE_ID(header) returned 401/403, expected 404'
}
if ($lineText -notmatch 'HTTP/\S+\s+404') {
  Fail "line-content FAKE_ID(header) expected HTTP 404, got: $($lineText -split "`n" | Select-Object -First 1)"
}
Write-Host '[smoke-all] line-content FAKE_ID(header) returned 404 (as expected)' -ForegroundColor Green

Write-Host "[smoke-all] line-content(FAKE_ID, query token+tenant) => $BaseUrl/api/admin/chat/line-content/FAKE_ID?token=...&tenant=$Tenant"
$lineQueryUrl = "$BaseUrl/api/admin/chat/line-content/FAKE_ID?token=$([uri]::EscapeDataString($token))&tenant=$([uri]::EscapeDataString($Tenant))"
$lineOutputQuery = & $curlCmd -i -sS -X GET $lineQueryUrl 2>&1
$lineTextQuery = ($lineOutputQuery | Out-String)
if ($lineTextQuery -match 'HTTP/\S+\s+401' -or $lineTextQuery -match 'HTTP/\S+\s+403') {
  Fail 'line-content FAKE_ID(query) returned 401/403, expected 404'
}
if ($lineTextQuery -notmatch 'HTTP/\S+\s+404') {
  Fail "line-content FAKE_ID(query) expected HTTP 404, got: $($lineTextQuery -split "`n" | Select-Object -First 1)"
}
Write-Host '[smoke-all] line-content FAKE_ID(query) returned 404 (as expected)' -ForegroundColor Green

if (-not [string]::IsNullOrWhiteSpace($LineContentId)) {
  Write-Host "[smoke-all] line-content(real id) => $BaseUrl/api/admin/chat/line-content/$LineContentId"
  $realOutput = & $curlCmd -i -sS -X GET "$BaseUrl/api/admin/chat/line-content/$LineContentId" -H "Authorization: Bearer $token" -H "x-tenant: $Tenant" 2>&1
  $realText = ($realOutput | Out-String)
  if ($realText -match 'HTTP/\S+\s+401' -or $realText -match 'HTTP/\S+\s+403') {
    Fail 'line-content real-id returned 401/403'
  }
  if ($realText -notmatch 'HTTP/\S+\s+200') {
    Fail "line-content real-id expected HTTP 200, got: $($realText -split "`n" | Select-Object -First 1)"
  }
  if ($realText -notmatch '(?i)content-type:\s*(image/|application/octet-stream)') {
    Fail 'line-content real-id missing image/* or application/octet-stream content-type'
  }
  Write-Host '[smoke-all] line-content real-id returned valid binary content-type' -ForegroundColor Green
} else {
  Write-Host '[smoke-all] WARN: LineContentId not provided; skip real-id content-type check' -ForegroundColor Yellow
}

Write-Host '[smoke-all] OK: health, login, bots, SSE, and line-content checks passed' -ForegroundColor Green
