#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param(
  [string]$Tenant = "bn9",
  [string]$BaseUrl = "http://127.0.0.1:3000",
  [string]$Email  = "root@bn9.local",
  [string]$Password = "bn9@12345",
  [int]$FrontendPort = 5555,
  [int]$BackendPort  = 3000,
  [int]$RedisPort    = 6380,
  [switch]$SkipFrontend,
  [switch]$SkipRedis,
  [switch]$StartBackend,
  [switch]$StartFrontend,
  [switch]$InstallDeps
)

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "✔ $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "⚠ $msg" -ForegroundColor Yellow }
function Fail($msg) { Write-Host "✘ $msg" -ForegroundColor Red }

function Find-RepoRoot {
  $d = (Get-Location).Path
  for ($i=0; $i -lt 8; $i++) {
    if (Test-Path (Join-Path $d "bn88-backend-v12\package.json")) { return $d }
    $parent = Split-Path $d -Parent
    if ($parent -eq $d) { break }
    $d = $parent
  }
  throw "หา repo root ไม่เจอ (ต้องมี bn88-backend-v12\package.json) — ตอนนี้อยู่: $((Get-Location).Path)"
}

function IsPortListening([int]$port) {
  try {
    $c = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue
    return [bool]$c
  } catch { return $false }
}

function HttpJson($method, $url, $headers, $bodyJson) {
  if ($bodyJson) {
    return Invoke-RestMethod -Method $method -Uri $url -Headers $headers -ContentType "application/json" -Body $bodyJson -TimeoutSec 10
  } else {
    return Invoke-RestMethod -Method $method -Uri $url -Headers $headers -TimeoutSec 10
  }
}

function Start-NpmDev($cwd, $name, $logDir) {
  if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
  $ts = Get-Date -Format "yyyyMMdd-HHmmss"
  $out = Join-Path $logDir "$name.out.$ts.log"
  $err = Join-Path $logDir "$name.err.$ts.log"
  Step "Start $name (npm run dev) @ $cwd"
  Start-Process -FilePath "pwsh" -WorkingDirectory $cwd -WindowStyle Normal -ArgumentList @(
    "-NoLogo","-NoProfile","-ExecutionPolicy","Bypass","-Command",
    "npm run dev 1>`"$out`" 2>`"$err`""
  ) | Out-Null
  Ok "$name started (logs: $out , $err)"
}

# ---------------- main ----------------
$root = Find-RepoRoot
$be = Join-Path $root "bn88-backend-v12"
$fe = Join-Path $root "bn88-frontend-dashboard-v12"
$logDir = Join-Path $root "logs"

Step "Repo root"
Ok $root
Ok "backend=$be"
Ok "frontend=$fe"

Step "กันหลงโฟลเดอร์ (ต้อง True ทั้งคู่)"
"{0}" -f (Test-Path (Join-Path $be "package.json"))
"{0}" -f (Test-Path (Join-Path $fe "package.json")) | Out-Null
if (!(Test-Path (Join-Path $be "package.json"))) { throw "missing: $be\package.json" }
if (!(Test-Path (Join-Path $fe "package.json"))) { throw "missing: $fe\package.json" }
Ok "package.json OK"

Step "Node/NPM"
try {
  $nodeV = (node -v) 2>$null
  $npmV  = (npm -v) 2>$null
  Ok "node=$nodeV  npm=$npmV"
} catch {
  throw "ไม่เจอ node/npm ใน PATH"
}

if ($InstallDeps) {
  Step "Install deps (npm ci) backend+frontend"
  Push-Location $be
  npm ci
  Pop-Location

  if (-not $SkipFrontend) {
    Push-Location $fe
    npm ci
    Pop-Location
  }
  Ok "deps installed"
}

if ($StartBackend) { Start-NpmDev -cwd $be -name "backend" -logDir $logDir }
if (($StartFrontend) -and (-not $SkipFrontend)) { Start-NpmDev -cwd $fe -name "frontend" -logDir $logDir }

Step "Ports"
if (IsPortListening $BackendPort) { Ok "Backend port :$BackendPort LISTEN" } else { Warn "Backend port :$BackendPort NOT listening" }
if (-not $SkipFrontend) {
  if (IsPortListening $FrontendPort) { Ok "Frontend port :$FrontendPort LISTEN" } else { Warn "Frontend port :$FrontendPort NOT listening" }
}
if (-not $SkipRedis) {
  if (IsPortListening $RedisPort) { Ok "Redis port :$RedisPort LISTEN" } else { Warn "Redis port :$RedisPort NOT listening (optional ได้)" }
}

Step "Backend health"
try {
  $h = HttpJson GET "$BaseUrl/api/health" @{} $null
  Ok "/api/health OK"
} catch {
  Fail "/api/health FAIL => $($_.Exception.Message)"
  throw
}

Step "Admin login -> token"
$token = $null
try {
  $loginBody = @{ email=$Email; password=$Password } | ConvertTo-Json
  $login = HttpJson POST "$BaseUrl/api/admin/auth/login" @{} $loginBody
  if (-not $login.token) { throw "no token in response" }
  $token = $login.token
  Ok "login OK (token len=$($token.Length))"
} catch {
  Fail "login FAIL => $($_.Exception.Message)"
  throw
}

Step "GET /api/admin/bots"
try {
  $headers = @{ Authorization="Bearer $token"; "x-tenant"=$Tenant }
  $bots = HttpJson GET "$BaseUrl/api/admin/bots" $headers $null
  $count = 0
  if ($bots.items) { $count = $bots.items.Count }
  Ok "bots OK (items=$count)"
} catch {
  Fail "bots FAIL => $($_.Exception.Message)"
  Warn "ถ้าเป็น 401/403 = โฟกัส auth/permission (manageBots) ก่อน"
}

Step "SSE header check (ไม่ต้องสตรีมจริง)"
try {
  $sseUrl = "$BaseUrl/api/live/$Tenant?token=$token"
  $hdr = & curl.exe -s -D - -o NUL $sseUrl
  if ($LASTEXITCODE -ne 0) { throw "curl exit=$LASTEXITCODE" }
  if ($hdr -match "text/event-stream") { Ok "SSE endpoint ตอบ header text/event-stream" }
  else { Warn "SSE header ไม่เจอ text/event-stream (ดู output ด้านบน)" }
} catch {
  Warn "SSE check skipped/failed => $($_.Exception.Message)"
}

Step "Cloudflare tunnel config (ถ้ามี)"
$cf = Join-Path $env:USERPROFILE ".cloudflared\config-bn88.yml"
if (Test-Path $cf) { Ok "found $cf" } else { Warn "not found $cf (ถ้าจะผูก api.bn9.app ต้องมีไฟล์นี้)" }

Step "Quick scan: auth guards + line-content"
try {
  Push-Location $be
  $hits = & rg -n "middleware/authGuard\.ts|src/mw/auth\.ts|requirePermission\(|manageBots|line-content|/api/live/" src -S
  Pop-Location
  Ok "rg scan OK (ดูรายการด้านบน)"
} catch {
  Warn "rg ไม่พร้อม หรือหาไม่เจอ (ติดตั้ง ripgrep/rg ก่อน)"
}

Ok "DONE"