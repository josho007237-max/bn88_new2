$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:3000"
$tenant = if ([string]::IsNullOrWhiteSpace($Env:TENANT)) { "bn9" } else { $Env:TENANT.Trim() }
$adminEmail = $Env:ADMIN_EMAIL
$adminPassword = $Env:ADMIN_PASSWORD
$steps = @()
$allPassed = $true

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
    $msg = if ($passed) { "listening" } else { "not reachable" }
    Write-Step "Port $port" $passed $msg
  } catch {
    Write-Step "Port $port" $false "error checking port: $_"
  }
}

try {
  $health = Invoke-RestMethod -Uri "$baseUrl/api/health" -UseBasicParsing
  Write-Step "/api/health" $true "ok=$($health.ok)"
} catch {
  Write-Step "/api/health" $false "$_"
}

if (-not $adminEmail -or -not $adminPassword) {
  Write-Step "admin login" $false "ADMIN_EMAIL/ADMIN_PASSWORD missing"
  $token = $null
} else {
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
    $curlArgs = "-N", "$baseUrl/api/live/$tenant?token=$token", "--max-time", "5"
    $proc = Start-Process -FilePath "curl.exe" -ArgumentList $curlArgs -NoNewWindow -RedirectStandardOutput "${Env:TEMP}\p0-sse.log" -RedirectStandardError "${Env:TEMP}\p0-sse.err" -PassThru
    $proc | Wait-Process
    $exit = $proc.ExitCode
    if ($exit -eq 0) {
      Write-Step "SSE /api/live" $true "curl exit 0"
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
