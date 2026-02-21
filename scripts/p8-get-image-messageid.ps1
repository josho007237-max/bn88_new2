$ErrorActionPreference = 'Stop'

param(
  [string]$BaseUrl = 'https://hook.bn9.app',
  [string]$Tenant = 'bn9',
  [string]$Email = 'root@bn9.local',
  [string]$Password = 'bn9@12345'
)

$apiBase = "$BaseUrl/api"
$healthUrl = "$apiBase/health"

try {
  $health = Invoke-WebRequest -Method Get -Uri $healthUrl -UseBasicParsing
  if ($health.StatusCode -ne 200) {
    Write-Host 'tunnel ยังไม่พร้อม' -ForegroundColor Yellow
    exit 1
  }
} catch {
  Write-Host 'tunnel ยังไม่พร้อม' -ForegroundColor Yellow
  exit 1
}

$loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json
$login = Invoke-RestMethod -Method Post -Uri "$apiBase/admin/auth/login" -ContentType 'application/json' -Body $loginBody

if (-not $login -or -not $login.token) {
  Write-Host 'login failed: token not found' -ForegroundColor Red
  exit 1
}

$headers = @{ Authorization = "Bearer $($login.token)"; 'x-tenant' = $Tenant }

$sessions = Invoke-RestMethod -Method Get -Uri "$apiBase/admin/chat/sessions?limit=20" -Headers $headers
$items = @($sessions.items)

if ($items.Count -eq 0) {
  Write-Host 'ยังไม่มี LINE ยิงเข้า ให้ส่งข้อความ+รูปเข้ามาก่อน' -ForegroundColor Yellow
  exit 0
}

$session = $items[0]
$sessionId = "$($session.id)"
Write-Host "sessionId: $sessionId"

$msgs = Invoke-RestMethod -Method Get -Uri "$apiBase/admin/chat/messages?sessionId=$([uri]::EscapeDataString($sessionId))&limit=50" -Headers $headers
$messageItems = @($msgs.items)

$filtered = @($messageItems | Where-Object {
  $type = "$($_.type)".ToLowerInvariant()
  $hasAttachmentLike = (
    ($null -ne $_.attachment) -or
    ($null -ne $_.attachmentId) -or
    ($null -ne $_.attachmentUrl) -or
    ($null -ne $_.contentId) -or
    ($null -ne $_.lineContentId) -or
    ($null -ne $_.lineMessageId)
  )

  $type -eq 'image' -or $hasAttachmentLike
})

if ($filtered.Count -eq 0) {
  Write-Host 'ไม่พบ message ที่เป็นรูปหรือมี candidate id'
  exit 0
}

foreach ($m in $filtered) {
  $candidates = @()

  if ($m.lineContentId) { $candidates += "lineContentId=$($m.lineContentId)" }
  if ($m.contentId) { $candidates += "contentId=$($m.contentId)" }
  if ($m.lineMessageId) { $candidates += "lineMessageId=$($m.lineMessageId)" }
  if ($m.attachmentId) { $candidates += "attachmentId=$($m.attachmentId)" }
  if ($m.attachment) { $candidates += "attachment=$($m.attachment)" }
  if ($m.id) { $candidates += "id=$($m.id)" }

  Write-Host '------------------------------'
  Write-Host ("message id={0} type={1}" -f $m.id, $m.type)
  if ($m.text) { Write-Host ("text={0}" -f $m.text) }
  if ($m.attachmentUrl) { Write-Host ("attachmentUrl={0}" -f $m.attachmentUrl) }

  Write-Host 'candidate IDs:'
  if ($candidates.Count -gt 0) {
    $candidates | ForEach-Object { Write-Host ("- {0}" -f $_) }
  } else {
    Write-Host '- (none)'
  }
}
