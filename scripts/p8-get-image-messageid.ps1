$ErrorActionPreference = 'Stop'

param(
  [string]$ApiBase = 'https://hook.bn9.app/api',
  [string]$Tenant = 'bn9'
)

function Try-Login($Email, $Password) {
  try {
    $body = @{ email = $Email; password = $Password } | ConvertTo-Json
    return Invoke-RestMethod -Method Post -Uri "$ApiBase/admin/auth/login" -ContentType 'application/json' -Body $body
  } catch {
    return $null
  }
}

try {
  $health = Invoke-WebRequest -Uri "$ApiBase/health" -Method Get -TimeoutSec 15
  if ($health.StatusCode -ne 200) {
    Write-Host "[p8-get-image-messageid] tunnel ยังไม่พร้อม (health=$($health.StatusCode))" -ForegroundColor Yellow
    exit 1
  }
} catch {
  Write-Host '[p8-get-image-messageid] tunnel ยังไม่พร้อม (https://hook.bn9.app/api/health ไม่ตอบ 200)' -ForegroundColor Yellow
  exit 1
}

$login = Try-Login 'root@bn9.local' 'bn9@12345'
if (-not $login -or -not $login.token) {
  $login = Try-Login 'admin@bn9.local' 'admin123'
}
if (-not $login -or -not $login.token) {
  Write-Host '[p8-get-image-messageid] login failed for both root/admin credentials' -ForegroundColor Yellow
  exit 1
}

$headers = @{ Authorization = "Bearer $($login.token)"; 'x-tenant' = $Tenant }

$sessions = Invoke-RestMethod -Method Get -Uri "$ApiBase/admin/chat/sessions?limit=20" -Headers $headers
$sessionItems = @($sessions.items)
if ($sessionItems.Count -eq 0) {
  Write-Host 'ยังไม่มี LINE ยิงเข้า ให้ส่งข้อความ+รูปเข้ามาก่อน' -ForegroundColor Yellow
  exit 0
}

$sessionId = "$($sessionItems[0].id)"
Write-Host "[p8-get-image-messageid] sessionId: $sessionId"

$msgs = Invoke-RestMethod -Method Get -Uri "$ApiBase/admin/chat/messages?sessionId=$([uri]::EscapeDataString($sessionId))&limit=50" -Headers $headers
$items = @($msgs.items)

$filtered = @($items | Where-Object {
  $m = $_
  $type = "$($m.type)".ToUpperInvariant()
  $legacyType = "$($m.messageType)".ToUpperInvariant()
  ($type -eq 'IMAGE') -or
  ($legacyType -eq 'IMAGE') -or
  $m.attachmentUrl -or
  $m.attachmentId -or
  $m.contentId -or
  $m.lineContentId -or
  $m.lineMessageId
})

if ($filtered.Count -eq 0) {
  Write-Host '[p8-get-image-messageid] no image/attachment-like message in latest 50 messages' -ForegroundColor Yellow
  exit 0
}

foreach ($m in $filtered) {
  $candidates = @(
    "$($m.lineContentId)",
    "$($m.contentId)",
    "$($m.attachmentId)",
    "$($m.lineMessageId)",
    "$($m.id)"
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

  Write-Host "--- messageId=$($m.id) type=$($m.type) legacyType=$($m.messageType)"
  Write-Host "attachmentUrl=$($m.attachmentUrl)"
  Write-Host ("candidateIds=" + ($candidates -join ', ')) -ForegroundColor Cyan
}
