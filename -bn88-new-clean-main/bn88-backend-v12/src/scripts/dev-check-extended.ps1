param(
  [string]$Base = "http://127.0.0.1:3000/api",
  [string]$Tenant = "bn9"
)

Write-Host "=== BN9 DEV CHECK EXTENDED ===" -ForegroundColor Cyan

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

# 1) health
Write-Host "`n#1) /health" -ForegroundColor Yellow
$health = Invoke-RestMethod "$Base/health"
$health | Format-Table
if (-not $health.ok) { throw "health not ok" }

# 2) login
Write-Host "`n#2) /admin/auth/login" -ForegroundColor Yellow
$LoginEmail = if ($env:BN88_ADMIN_EMAIL) { $env:BN88_ADMIN_EMAIL } else { "root@bn9.local" }
$LoginPassword = if ($env:BN88_ADMIN_PASSWORD) { $env:BN88_ADMIN_PASSWORD } else { "bn9@12345" }
$loginUrl = "$Base/admin/auth/login"
$body = @{ email = $LoginEmail; password = $LoginPassword } | ConvertTo-Json
$login = Invoke-RestMethod -Method Post -Uri $loginUrl `
  -ContentType "application/json" -Body $body
$token = $login.token
if (-not $token) { throw "no token from login" }
$H = @{ Authorization = "Bearer $token"; "x-tenant" = $Tenant }
Write-Host "login ok" -ForegroundColor Green

# 3) bots
Write-Host "`n#3) /bots" -ForegroundColor Yellow
$bots = Invoke-RestMethod "$Base/bots" -Headers $H
$bots.items | Format-Table id,name,platform
$botId = ($bots.items | Select-Object -First 1).id
if (-not $botId) { throw "no bot found" }
Write-Host "use botId = $botId" -ForegroundColor Green

# 4) stats
Write-Host "`n#4) /stats/daily" -ForegroundColor Yellow
$daily = Invoke-RestMethod "$Base/stats/daily?botId=$botId" -Headers $H
$daily | Format-List

# 5) recent cases
Write-Host "`n#5) /cases/recent" -ForegroundColor Yellow
$cases = Invoke-RestMethod "$Base/cases/recent?botId=$botId&limit=5" -Headers $H
$cases.items | Format-Table id,userId,text,kind,createdAt

# 6) knowledge list
Write-Host "`n#6) /admin/ai/knowledge" -ForegroundColor Yellow
$kdocs = Invoke-RestMethod "$Base/admin/ai/knowledge" -Headers $H
$kdocs.items | Format-Table id,title,updatedAt

# 7) persona presets
Write-Host "`n#7) /admin/ai/presets" -ForegroundColor Yellow
$presets = Invoke-RestMethod "$Base/admin/ai/presets" -Headers $H
$presets.items | Format-Table id,name,model,temperature

# 8) memory set/get
Write-Host "`n#8) /memory/set + /memory/get" -ForegroundColor Yellow
$memBody = @{ userRef = "test-user-1"; key = "nick"; value = "คุณบีเอ็นเก้า"; tags = @("test","dev") } | ConvertTo-Json
$ms = Invoke-RestMethod -Method Post -Uri "$Base/memory/set" -Headers $H `
  -ContentType "application/json" -Body $memBody
$ms.item | Format-List

$mg = Invoke-RestMethod "$Base/memory/get?userRef=test-user-1&key=nick" -Headers $H
$mg.item | Format-List

# 9) AI answer
Write-Host "`n#9) /ai/answer" -ForegroundColor Yellow
$askBody = @{
  botId = $botId
  message = "สรุประบบ BN9 ให้หน่อย 2 บรรทัด"
} | ConvertTo-Json
$answer = Invoke-RestMethod -Method Post -Uri "$Base/ai/answer" -Headers $H `
  -ContentType "application/json" -Body $askBody
$answer | Format-List

Write-Host "`nALL EXTENDED CHECKS PASSED (ถ้าไม่ throw error ระหว่างทาง) ✅" -ForegroundColor Green
$portMatch = [regex]::Match($Base, ":(\d+)")
$Port = if ($env:PORT) { [int]$env:PORT } elseif ($portMatch.Success) { [int]$portMatch.Groups[1].Value } else { 3000 }
$HealthUrl = "$Base/health"
Write-Host "Summary: PORT=$Port, HEALTH=$HealthUrl" -ForegroundColor DarkCyan
