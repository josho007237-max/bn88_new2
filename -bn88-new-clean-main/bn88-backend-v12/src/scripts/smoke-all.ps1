param(
  [string]$BaseUrl = "http://127.0.0.1:3000",
  [string]$Tenant  = "bn9",
  [string]$Email   = "root@bn9.local",
  [string]$Password= "bn9@12345",
  [switch]$ExpectSse,
  [int]$SseMaxTimeSec = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:Failed = $false

function Write-Step([string]$name, [bool]$ok, [string]$detail="") {
  if ($ok) {
    Write-Host ("✅ {0}" -f $name) -ForegroundColor Green
  } else {
    Write-Host ("❌ {0} :: {1}" -f $name, $detail) -ForegroundColor Red
    $script:Failed = $true
  }
}

function Write-Warn([string]$name, [string]$detail="") {
  Write-Host ("⚠️ {0} :: {1}" -f $name, $detail) -ForegroundColor Yellow
}

function Assert([bool]$cond, [string]$msg) {
  if (-not $cond) { throw $msg }
}

function Try-Step([string]$name, [scriptblock]$fn, [switch]$NonFatal) {
  try {
    & $fn
    Write-Step $name $true
  } catch {
    $m = $_.Exception.Message
    if ($NonFatal) { Write-Warn $name $m }
    else { Write-Step $name $false $m }
  }
}

Write-Host "`n# smoke-all.ps1" -ForegroundColor Cyan
Write-Host ("BaseUrl={0} Tenant={1}" -f $BaseUrl, $Tenant) -ForegroundColor DarkCyan

# 1) Health
Try-Step "health (/api/health)" {
  $h = Invoke-RestMethod "$BaseUrl/api/health"
  Assert ($h.ok -eq $true) "health.ok != true"
  Assert ($h.adminApi -eq $true) "health.adminApi != true (ENABLE_ADMIN_API=1?)"
} 

# 2) Login -> token
$token = $null
Try-Step "login (/api/admin/auth/login)" {
  $body = @{ email=$Email; password=$Password } | ConvertTo-Json
  $r = Invoke-RestMethod -Method Post "$BaseUrl/api/admin/auth/login" -Body $body -ContentType "application/json"
  $token = $r.token
  Assert ([string]::IsNullOrWhiteSpace($token) -eq $false) "missing token"
  Assert ($token.Length -gt 50) ("token too short len={0}" -f $token.Length)
  Write-Host ("tokenLen={0}" -f $token.Length) -ForegroundColor DarkGray
}

# 3) Bots
$bots = $null
Try-Step "bots (/api/admin/bots)" {
  Assert ($token) "token is null (login failed?)"
  $bots = Invoke-RestMethod "$BaseUrl/api/admin/bots" -Headers @{ Authorization="Bearer $token"; "x-tenant"=$Tenant }
  Assert ($bots.ok -eq $true) "bots.ok != true"
  Assert ($bots.items.Count -gt 0) "bots.items empty"
  Write-Host ("botsCount={0}" -f $bots.items.Count) -ForegroundColor DarkGray
}

# 4) SSE (optional; default WARN เพราะตอนนี้ยังติด auth)
Try-Step "sse (/api/live/:tenant)" {
  Assert ($token) "token is null"
  $enc = [uri]::EscapeDataString($token)
  $url = "$BaseUrl/api/live/$Tenant?token=$enc"
  $curl = (Get-Command curl.exe -ErrorAction Stop).Source

  # try without x-tenant first (FE style)
  $out = & $curl "-sS" "-i" "-N" $url "--max-time" "$SseMaxTimeSec" 2>&1 | Out-String
  if ($out -match "HTTP/1\.1 200" -and $out -match "text/event-stream") {
    return
  }

  # retry with x-tenant header (debug style)
  $out2 = & $curl "-sS" "-i" "-N" "-H" ("x-tenant: {0}" -f $Tenant) $url "--max-time" "$SseMaxTimeSec" 2>&1 | Out-String
  if ($out2 -match "HTTP/1\.1 200" -and $out2 -match "text/event-stream") {
    Write-Warn "sse retry needed" "works only when x-tenant header is present (FE EventSource can't send headers)"
    return
  }

  throw ("SSE not 200. lastResponse=" + (($out2.Trim() | Select-Object -First 1)))
} -NonFatal:(!$ExpectSse)

# 5) LINE webhook route exists? (POST should NOT be 404)
Try-Step "line webhook mounted (POST /api/webhooks/line)" {
  $curl = (Get-Command curl.exe -ErrorAction Stop).Source
  $out = & $curl "-sS" "-i" "-X" "POST" "$BaseUrl/api/webhooks/line" "-H" "Content-Type: application/json" "-d" "{}" "--max-time" "5" 2>&1 | Out-String

  # route exists: status often 400/401/500 (signature missing / env missing) BUT not 404
  Assert ($out -notmatch "HTTP/1\.1 404") "webhook returned 404 (route not mounted)"
} -NonFatal

Write-Host ""
if ($script:Failed) {
  Write-Host "SMOKE RESULT: FAIL" -ForegroundColor Red
  exit 1
} else {
  Write-Host "SMOKE RESULT: PASS (SSE/webhook may be WARN)" -ForegroundColor Green
  exit 0
}
