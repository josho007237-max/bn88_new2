param(
  [string]$Base = "",
  [string]$Tenant = "bn9"
)

Write-Host "=== BN9 DEV CHECK ===" -ForegroundColor Cyan

# --------------------------------------------------------------------
# 0) Working dir guard (package.json + src)
# --------------------------------------------------------------------
$ExpectedRoot = "C:\BN88\BN88-new-clean\bn88-backend-v12"
$Cwd = (Get-Location).Path
$PkgOk = Test-Path (Join-Path $Cwd "package.json")
$SrcOk = Test-Path (Join-Path $Cwd "src")
if (-not ($PkgOk -and $SrcOk)) {
  Write-Host "ไม่พบ package.json หรือ src ในโฟลเดอร์นี้: $Cwd" -ForegroundColor Red
  Write-Host "กรุณาใช้คำสั่ง: cd $ExpectedRoot" -ForegroundColor Yellow
  exit 1
}

# --------------------------------------------------------------------
# 0) Resolve PORT + Base
# --------------------------------------------------------------------
$Port = if ($env:PORT) { [int]$env:PORT } else { 3000 }
if (-not $Base) { $Base = "http://127.0.0.1:$Port/api" }
Write-Host "Base = $Base (PORT=$Port)" -ForegroundColor DarkCyan

# --------------------------------------------------------------------
# 0.1) netstat check
# --------------------------------------------------------------------
Write-Host "`n#0.1) port 3000 owning process" -ForegroundColor Yellow
$listenPid3000 = (Get-NetTCPConnection -LocalPort 3000 -State Listen).OwningProcess
if ($listenPid3000 -is [array]) {
  $listenPid3000 = ($listenPid3000 | Where-Object { $_ -gt 0 } | Select-Object -First 1)
}
if ($listenPid3000) {
  $listenProc3000 = Get-CimInstance Win32_Process -Filter "ProcessId=$listenPid3000" -ErrorAction SilentlyContinue
  $listenCommand3000 = if ($listenProc3000) { $listenProc3000.CommandLine } else { $null }
  Write-Host "PID(3000): $listenPid3000" -ForegroundColor Green
  Write-Host "CommandLine(3000): $listenCommand3000"
} else {
  Write-Host "not listening on :3000 (Get-NetTCPConnection)" -ForegroundColor Red
}

# --------------------------------------------------------------------
# 0.2) netstat check
# --------------------------------------------------------------------
Write-Host "`n#0.2) netstat :$Port" -ForegroundColor Yellow
$netstatOk = $false
try {
  $netstatLine = netstat -ano | Select-String -Pattern "LISTENING" | Select-String -Pattern ":$Port\s"
  if ($netstatLine) {
    $netstatOk = $true
    $netstatLine | Select-Object -First 1 | ForEach-Object { Write-Host $_ -ForegroundColor Green }
  } else {
    Write-Host "not listening on :$Port" -ForegroundColor Red
  }
} catch {
  Write-Host "netstat error: $($_.Exception.Message)" -ForegroundColor Red
}

# --------------------------------------------------------------------
# 0.2) curl /api/health
# --------------------------------------------------------------------
Write-Host "`n#0.2) curl /api/health" -ForegroundColor Yellow
$healthUrl = "$Base/health"
$healthOk = $false
$curlOut = & curl.exe -sS -w "`n%{http_code}" "$healthUrl" 2>&1
$curlOk = ($LASTEXITCODE -eq 0)
if (-not $curlOk) {
  Write-Host "curl error: $curlOut" -ForegroundColor Red
  $healthOk = $false
} else {
  $parts = $curlOut -split "`n"
  $status = $parts[-1].Trim()
  $body = ($parts[0..($parts.Length - 2)] -join "`n").Trim()
  Write-Host $body
  if ($status -eq "200") { $healthOk = $true }
  Write-Host "status=$status" -ForegroundColor $(if ($healthOk) { "Green" } else { "Red" })
}

# Summary preflight
if ($netstatOk -and $healthOk) {
  Write-Host "Preflight PASS ✅" -ForegroundColor Green
} else {
  Write-Host "Preflight FAIL ❌ (netstat=$netstatOk, health=$healthOk)" -ForegroundColor Red
}

# --------------------------------------------------------------------
# 1) /health
# --------------------------------------------------------------------
Write-Host "`n#1) GET /health" -ForegroundColor Yellow
$health = Invoke-RestMethod "$Base/health"
$health | Format-Table
if (-not $health.ok) { throw "health not ok" }

# --------------------------------------------------------------------
# 2) login admin (JWT)
# --------------------------------------------------------------------
Write-Host "`n#2) POST /admin/auth/login (admin)" -ForegroundColor Yellow
$LoginEmail = if ($env:BN88_ADMIN_EMAIL) { $env:BN88_ADMIN_EMAIL } else { "root@bn9.local" }
$LoginPassword = if ($env:BN88_ADMIN_PASSWORD) { $env:BN88_ADMIN_PASSWORD } else { "bn9@12345" }
$loginUrl = "$Base/admin/auth/login"
$body = @{ email = $LoginEmail; password = $LoginPassword } | ConvertTo-Json
$login = Invoke-RestMethod -Method Post -Uri $loginUrl `
  -ContentType "application/json" -Body $body

$token = $login.token
if (-not $token) { throw "no token from login" }
$H = @{
  Authorization = "Bearer $token"
  "x-tenant"    = $Tenant
}
Write-Host "login ok, token acquired" -ForegroundColor Green

# --------------------------------------------------------------------
# 3) list bots
# --------------------------------------------------------------------
Write-Host "`n#3) GET /bots" -ForegroundColor Yellow
$bots = Invoke-RestMethod "$Base/bots" -Headers $H
$bots.items | Format-Table id,name,platform

$botId = ($bots.items | Select-Object -First 1).id
if (-not $botId) { throw "no bot found" }
Write-Host "use botId = $botId" -ForegroundColor Green

# --------------------------------------------------------------------
# 4) GET /admin/bots/:id/secrets (ทดสอบ JWT + guard admin)
# --------------------------------------------------------------------
Write-Host "`n#4) GET /admin/bots/$botId/secrets" -ForegroundColor Yellow
$secrets = Invoke-RestMethod "$Base/admin/bots/$botId/secrets" -Headers $H
$secrets | Format-List
Write-Host "secrets ok (masked) ✅" -ForegroundColor Green

# --------------------------------------------------------------------
# 5) GET /dev/line-ping/:botId  (ไม่บังคับต้องผ่าน แค่โชว์สถานะ)
# --------------------------------------------------------------------
Write-Host "`n#5) GET /dev/line-ping/$botId" -ForegroundColor Yellow
try {
  $ping = Invoke-RestMethod "$Base/dev/line-ping/$botId" -Headers $H
  $ping | Format-List
  if ($ping.ok -and $ping.status -eq 200) {
    Write-Host "line ping status = 200 (OK)" -ForegroundColor Green
  } else {
    Write-Host "line ping status = $($ping.status) ($($ping.message))" -ForegroundColor DarkYellow
  }
} catch {
  Write-Host "line ping error: $($_.Exception.Message)" -ForegroundColor Red
}

# --------------------------------------------------------------------
# 6) GET /stats/daily?botId=...
# --------------------------------------------------------------------
Write-Host "`n#6) GET /stats/daily" -ForegroundColor Yellow
$daily = Invoke-RestMethod "$Base/stats/daily?botId=$botId" -Headers $H
$daily | Format-List

# --------------------------------------------------------------------
# 7) GET /cases/recent?botId=...&limit=5
# --------------------------------------------------------------------
Write-Host "`n#7) GET /cases/recent" -ForegroundColor Yellow
$cases = Invoke-RestMethod "$Base/cases/recent?botId=$botId&limit=5" -Headers $H
$cases.items | Format-Table id,userId,text,kind,createdAt

Write-Host "`nALL CHECKS PASSED ✅" -ForegroundColor Green
Write-Host "Summary: PORT=$Port, HEALTH=$healthUrl" -ForegroundColor DarkCyan
