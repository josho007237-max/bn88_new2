$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:3000"
$tenant = if ([string]::IsNullOrWhiteSpace($Env:TENANT)) { "bn9" } else { $Env:TENANT.Trim() }
$adminEmail = $Env:ADMIN_EMAIL
$adminPassword = $Env:ADMIN_PASSWORD
if (-not $adminEmail -or -not $adminPassword) {
  $adminEmail = $Env:DEV_ADMIN_EMAIL
  $adminPassword = $Env:DEV_ADMIN_PASSWORD
}
if (-not $adminEmail -or -not $adminPassword) {
  $adminEmail = "root@bn9.local"
  $adminPassword = "bn9@12345"
}
$steps = @()
$allPassed = $true
$port3000Listening = $false

function Write-Step($name, $passed, $message) {
  $status = if ($passed) { "PASS" } else { "FAIL" }
  Write-Host "$name : $status - $message"
  if (-not $passed) { $global:allPassed = $false }
  $steps += [pscustomobject]@{ Name = $name; Passed = $passed; Message = $message }
}

Write-Host "=== P0 smoke checks ==="

foreach ($port in @(3000, 6380)) {
  try {
    $conn = Test-NetConnection -ComputerName "localhost" -Port $port -WarningAction SilentlyContinue
    $passed = $conn.TcpTestSucceeded
    if ($port -eq 3000) { $port3000Listening = $passed }
    $msg = if ($passed) { "listening" } else { "not reachable" }
    Write-Step "Port $port" $passed $msg
  } catch {
    Write-Step "Port $port" $false "error checking port: $_"
  }
}

if (-not $port3000Listening) {
  Write-Host "ต้องรัน npm run dev ก่อน"
  Write-Host "Some checks failed"
  exit 1
}

try {
  $health = Invoke-RestMethod -Uri "$baseUrl/api/health" -UseBasicParsing
  Write-Step "/api/health" $true "ok=$($health.ok)"
} catch {
  Write-Step "/api/health" $false "$_"
}

if (-not ($steps | Where-Object { $_.Name -eq "Port 3000" -and -not $_.Passed })) {
  try {
    $body = @{ email = $adminEmail; password = $adminPassword } | ConvertTo-Json
    $resp = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/admin/auth/login" -Body $body -ContentType "application/json" -UseBasicParsing
    $token = $resp.token ?? $resp.accessToken
    if (-not $token) { throw 'token missing in login response' }
    Write-Step "admin login" $true "token received"
  } catch {
    Write-Step "admin login" $false "$_"
    $token = $null
  }
} else {
  Write-Step "admin login" $false "ไม่พบการฟังที่พอร์ต 3000 — ต้องรัน npm run dev ก่อน"
  $token = $null
}

if ($token) {
  try {
    $headers = @{ Authorization = "Bearer $token"; "x-tenant" = $tenant }
    $bots = Invoke-RestMethod -Uri "$baseUrl/api/admin/bots" -Headers $headers -UseBasicParsing
    Write-Step "/api/admin/bots" $true "bot count=$($bots.items.Count)"
  } catch {
    Write-Step "/api/admin/bots" $false "$_"
  }

  try {
    $headers = @{ Authorization = "Bearer $token"; "x-tenant" = $tenant }
    $sessions = Invoke-RestMethod -Uri "$baseUrl/api/admin/chat/sessions?limit=1" -Headers $headers -UseBasicParsing
    Write-Step "/api/admin/chat/sessions" $true "sessions=$($sessions.items.Count)"
  } catch {
    Write-Step "/api/admin/chat/sessions" $false "$_"
  }

  try {
    $curlArgs = "-i", "-N", "$baseUrl/api/live/$tenant?token=$token", "--max-time", "5"
    $proc = Start-Process -FilePath "curl.exe" -ArgumentList $curlArgs -NoNewWindow -RedirectStandardOutput "${Env:TEMP}\p0-sse.log" -RedirectStandardError "${Env:TEMP}\p0-sse.err" -PassThru
    $proc | Wait-Process
    $exit = $proc.ExitCode
    $sseHead = ""
    if (Test-Path "${Env:TEMP}\p0-sse.log") {
      $sseHead = (Get-Content "${Env:TEMP}\p0-sse.log" -TotalCount 20 | Out-String)
    }
    if ($exit -eq 0 -and $sseHead -match "HTTP/\S+\s+200") {
      Write-Step "SSE /api/live" $true "HTTP 200"
    } elseif ($sseHead -match "HTTP/\S+\s+401" -or $sseHead -match "HTTP/\S+\s+403") {
      Write-Step "SSE /api/live" $false "auth failed"
    } else {
      Write-Step "SSE /api/live" $false "curl exit $exit"
    }
  } catch {
    Write-Step "SSE /api/live" $false "$_"
  }
} else {
  Write-Step "Skipping protected calls" $false "no token"
}

Write-Host "\n=== Summary ==="
foreach ($s in $steps) {
  $stat = if ($s.Passed) { "PASS" } else { "FAIL" }
  Write-Host "$($s.Name): $stat - $($s.Message)"
}

if ($allPassed) { Write-Host "All checks passed"; exit 0 }
Write-Host "Some checks failed"; exit 1
