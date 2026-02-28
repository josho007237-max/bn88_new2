param(
  [string]$BaseUrl = 'http://127.0.0.1:3000',
  [string]$Tenant = 'bn9',
  [string]$Email = 'root@bn9.local',
  [string]$Password = 'bn9@12345',
  [string]$ReplyText = 'Phase5 smoke reply'
)

$ErrorActionPreference = 'Stop'
$failed = $false

function Write-Step([string]$Name, [int]$StatusCode, [bool]$Ok, [string]$Detail = '') {
  $tag = if ($Ok) { 'PASS' } else { 'FAIL' }
  $color = if ($Ok) { 'Green' } else { 'Red' }
  $suffix = if ([string]::IsNullOrWhiteSpace($Detail)) { '' } else { " | $Detail" }
  Write-Host "[$tag] $Name -> status=$StatusCode$suffix" -ForegroundColor $color
}

function Invoke-JsonRequest(
  [string]$Method,
  [string]$Url,
  [hashtable]$Headers = @{},
  [object]$Body = $null
) {
  try {
    $params = @{ Method = $Method; Uri = $Url; Headers = $Headers }
    if ($null -ne $Body) {
      $params.ContentType = 'application/json'
      $params.Body = ($Body | ConvertTo-Json -Depth 8 -Compress)
    }
    $resp = Invoke-RestMethod @params
    return @{ ok = $true; status = 200; body = $resp }
  } catch {
    $statusCode = 0
    $rawBody = ''
    if ($_.Exception.Response) {
      try { $statusCode = [int]$_.Exception.Response.StatusCode } catch { $statusCode = 0 }
      try {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $rawBody = $reader.ReadToEnd()
        $reader.Close()
      } catch { }
    }
    return @{ ok = $false; status = $statusCode; body = $rawBody; error = $_.Exception.Message }
  }
}

function Get-MessageArray([object]$Body) {
  if ($null -eq $Body) { return @() }
  if ($Body.items) { return @($Body.items) }
  if ($Body.messages) { return @($Body.messages) }
  if ($Body -is [System.Array]) { return @($Body) }
  return @()
}

$token = $null
$headers = $null
$sessionId = $null
$beforeMessages = @()

# 1) login
$loginRes = Invoke-JsonRequest -Method 'POST' -Url "$BaseUrl/api/admin/auth/login" -Body @{ email = $Email; password = $Password }
Write-Step -Name 'POST /api/admin/auth/login' -StatusCode $loginRes.status -Ok $loginRes.ok
if (-not $loginRes.ok) {
  $failed = $true
} else {
  $token = $loginRes.body.token
  if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Step -Name 'POST /api/admin/auth/login' -StatusCode 200 -Ok $false -Detail 'missing token'
    $failed = $true
  } else {
    $headers = @{ Authorization = "Bearer $token"; 'x-tenant' = $Tenant }
  }
}

# 2) list sessions
if (-not $failed) {
  $listRes = Invoke-JsonRequest -Method 'GET' -Url "$BaseUrl/api/admin/chat/sessions" -Headers $headers
  Write-Step -Name 'GET /api/admin/chat/sessions' -StatusCode $listRes.status -Ok $listRes.ok
  if (-not $listRes.ok) {
    $failed = $true
  } else {
    $items = $listRes.body.items
    if (-not $items -or $items.Count -lt 1) {
      Write-Step -Name 'GET /api/admin/chat/sessions' -StatusCode 200 -Ok $false -Detail 'no sessions'
      $failed = $true
    } else {
      $sessionId = $items[0].id
      if ([string]::IsNullOrWhiteSpace($sessionId)) {
        Write-Step -Name 'GET /api/admin/chat/sessions' -StatusCode 200 -Ok $false -Detail 'missing session id'
        $failed = $true
      }
    }
  }
}

# 3) get messages
if (-not $failed) {
  $msgRes = Invoke-JsonRequest -Method 'GET' -Url "$BaseUrl/api/admin/chat/sessions/$sessionId/messages" -Headers $headers
  if ($msgRes.ok) {
    $beforeMessages = Get-MessageArray -Body $msgRes.body
    Write-Step -Name 'GET /api/admin/chat/sessions/:id/messages' -StatusCode $msgRes.status -Ok $true -Detail ("count=$($beforeMessages.Count)")
  } else {
    Write-Step -Name 'GET /api/admin/chat/sessions/:id/messages' -StatusCode $msgRes.status -Ok $false
    $failed = $true
  }
}

# 4) reply
if (-not $failed) {
  $replyRes = Invoke-JsonRequest -Method 'POST' -Url "$BaseUrl/api/admin/chat/sessions/$sessionId/reply" -Headers $headers -Body @{ text = $ReplyText }
  Write-Step -Name 'POST /api/admin/chat/sessions/:id/reply' -StatusCode $replyRes.status -Ok $replyRes.ok
  if (-not $replyRes.ok) { $failed = $true }
}

# 5) reload messages
if (-not $failed) {
  $reloadRes = Invoke-JsonRequest -Method 'GET' -Url "$BaseUrl/api/admin/chat/sessions/$sessionId/messages" -Headers $headers
  if ($reloadRes.ok) {
    $afterMessages = Get-MessageArray -Body $reloadRes.body
    $beforeIds = @{}
    foreach ($m in $beforeMessages) {
      $id = [string]$m.id
      if (-not [string]::IsNullOrWhiteSpace($id)) { $beforeIds[$id] = $true }
    }
    $hasNew = $false
    foreach ($m in $afterMessages) {
      $id = [string]$m.id
      $text = [string]$m.text
      if ((-not [string]::IsNullOrWhiteSpace($id) -and -not $beforeIds.ContainsKey($id)) -or $text -eq $ReplyText) {
        $hasNew = $true
        break
      }
    }
    Write-Step -Name 'GET /api/admin/chat/sessions/:id/messages (reload)' -StatusCode $reloadRes.status -Ok $hasNew -Detail ("before=$($beforeMessages.Count), after=$($afterMessages.Count)")
    if (-not $hasNew) { $failed = $true }
  } else {
    Write-Step -Name 'GET /api/admin/chat/sessions/:id/messages (reload)' -StatusCode $reloadRes.status -Ok $false
    $failed = $true
  }
}

if ($failed) {
  Write-Host '[p5-chatcenter-smoke] RESULT: FAIL' -ForegroundColor Red
  exit 1
}

Write-Host '[p5-chatcenter-smoke] RESULT: PASS' -ForegroundColor Green
exit 0
