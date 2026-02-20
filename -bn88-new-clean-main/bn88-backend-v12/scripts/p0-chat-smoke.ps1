param(
  [string]$BaseUrl = "http://127.0.0.1:3000",
  [string]$Email = "root@bn9.local",
  [string]$Password = "bn9@12345",
  [string]$Tenant = "bn9"
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
  Write-Host "[p0-chat-smoke] FAIL: $Message" -ForegroundColor Red
  exit 1
}

function Pass([string]$Message) {
  Write-Host "[p0-chat-smoke] OK: $Message" -ForegroundColor Green
}

try {
  $loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress
  $login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/admin/auth/login" -ContentType "application/json" -Body $loginBody
  $token = if ($login.token) { "$($login.token)" } elseif ($login.accessToken) { "$($login.accessToken)" } else { "" }
  if ([string]::IsNullOrWhiteSpace($token)) { Fail "login token missing" }
  Pass "login 200"

  $headers = @{ Authorization = "Bearer $token"; "x-tenant" = $Tenant }

  $sessions = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/chat/sessions?limit=1" -Headers $headers
  if ($sessions.ok -ne $true) { Fail "sessions ok!=true" }
  $sessionId = "$($sessions.items[0].id)"
  if ([string]::IsNullOrWhiteSpace($sessionId)) { Fail "sessionId missing from /sessions" }
  Pass "GET /api/admin/chat/sessions 200 sessionId=$sessionId"

  $messages = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/chat/messages?sessionId=$sessionId&limit=5" -Headers $headers
  if ($messages.ok -ne $true) { Fail "messages ok!=true" }
  Pass "GET /api/admin/chat/messages 200"

  $metaBody = @{ hasProblem = $true } | ConvertTo-Json -Compress
  $patch = Invoke-RestMethod -Method Patch -Uri "$BaseUrl/api/admin/chat/sessions/$sessionId/meta" -Headers $headers -ContentType "application/json" -Body $metaBody
  if ($patch.ok -ne $true) { Fail "PATCH meta ok!=true" }
  Pass "PATCH /api/admin/chat/sessions/:id/meta 200"

  Write-Host "[p0-chat-smoke] DONE" -ForegroundColor Cyan
  exit 0
} catch {
  Fail $_.Exception.Message
}
