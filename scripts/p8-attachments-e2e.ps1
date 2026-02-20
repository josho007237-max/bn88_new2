$ErrorActionPreference = 'Stop'

param(
  [string]$ApiBase = 'http://127.0.0.1:3000/api',
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

$login = Try-Login 'root@bn9.local' 'bn9@12345'
if (-not $login -or -not $login.token) {
  $login = Try-Login 'admin@bn9.local' 'admin123'
}
if (-not $login -or -not $login.token) {
  Write-Host '[p8-attachments-e2e] login failed for both root/admin credentials' -ForegroundColor Yellow
  exit 1
}

$headers = @{ Authorization = "Bearer $($login.token)"; 'x-tenant' = $Tenant }

$bots = Invoke-RestMethod -Method Get -Uri "$ApiBase/admin/bots" -Headers $headers
$botId = $bots.items[0].id
Write-Host "[p8-attachments-e2e] botId: $botId"

$sessions = Invoke-RestMethod -Method Get -Uri "$ApiBase/admin/chat/sessions?botId=$([uri]::EscapeDataString($botId))&limit=20" -Headers $headers
$sessionId = $sessions.items[0].id
Write-Host "[p8-attachments-e2e] sessionId: $sessionId"

$msgs = Invoke-RestMethod -Method Get -Uri "$ApiBase/admin/chat/messages?sessionId=$([uri]::EscapeDataString($sessionId))&limit=50" -Headers $headers
$attachments = @($msgs.items | Where-Object {
  ("$($_.attachmentUrl)" -match '/line-content/') -or
  ("$($_.type)" -match 'IMAGE|FILE') -or
  ("$($_.messageType)" -match 'IMAGE|FILE')
})

Write-Host "[p8-attachments-e2e] attachment candidates: $($attachments.Count)"
$attachments | Select-Object -First 10 id, type, messageType, attachmentUrl | Format-Table -AutoSize

if ($attachments.Count -eq 0) {
  Write-Host '[p8-attachments-e2e] no attachment candidate found' -ForegroundColor Yellow
  exit 1
}

$pick = $attachments[0]
$contentKey = if ($pick.lineContentId) { "$($pick.lineContentId)" } elseif ($pick.contentId) { "$($pick.contentId)" } elseif ($pick.attachmentId) { "$($pick.attachmentId)" } else { "$($pick.id)" }
Write-Host "[p8-attachments-e2e] messageId: $($pick.id)"
Write-Host "[p8-attachments-e2e] contentKey: $contentKey"

$outFile = Join-Path $env:TEMP 'line.bin'
Invoke-WebRequest -Uri "$ApiBase/admin/chat/line-content/$([uri]::EscapeDataString($contentKey))" -Headers $headers -OutFile $outFile
Write-Host "[p8-attachments-e2e] wrote: $outFile"
Write-Host '[p8-attachments-e2e] open file to confirm image:' -ForegroundColor Cyan
Write-Host "Start-Process `"$outFile`"" -ForegroundColor Cyan
