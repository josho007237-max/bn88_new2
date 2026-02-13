param(
  [string]$Base = "http://127.0.0.1:3000",
  [string]$Tenant = "bn9",
  [int]$Port = 3000,
  [int]$WaitSeconds = 60
)

$AdminEmail = "root@bn9.local"
$AdminPassword = "bn9@12345"
$BackendRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")

function Test-PortListening {
  param([int]$CheckPort)
  try {
    $conn = Get-NetTCPConnection -LocalPort $CheckPort -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($conn) {
      $procId = $conn.OwningProcess
      $cmdLine = $null
      try {
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$procId" -ErrorAction SilentlyContinue
        if ($proc) { $cmdLine = $proc.CommandLine }
      } catch {}
      if ($cmdLine) {
        Write-Host "Port $CheckPort is listening (procId=$procId)" -ForegroundColor Green
        Write-Host "CommandLine: $cmdLine" -ForegroundColor DarkGray
      } else {
        Write-Host "Port $CheckPort is listening (procId=$procId)" -ForegroundColor Green
        Write-Host "CommandLine: <unknown>" -ForegroundColor DarkGray
      }
      return $true
    }
  } catch {
    Write-Host "Get-NetTCPConnection failed: $($_.Exception.Message)" -ForegroundColor Red
  }
  Write-Host "Port $CheckPort is not listening" -ForegroundColor Yellow
  return $false
}

Write-Host "=== DEV UP (backend) ===" -ForegroundColor Cyan
Write-Host "Base=$Base Tenant=$Tenant Port=$Port" -ForegroundColor DarkCyan

# 1) Ensure backend is running (port listen)
$isListening = Test-PortListening -CheckPort $Port
if (-not $isListening) {
  Write-Host "Starting backend in a new PowerShell window..." -ForegroundColor Yellow
  $cmd = "cd `"$BackendRoot`"; npm run dev"
  $proc = Start-Process powershell -ArgumentList "-NoExit", "-Command", $cmd -PassThru
  $procId = $proc.Id
  Write-Host "Started backend (procId=$procId)" -ForegroundColor Green

  $elapsed = 0
  while (-not (Test-PortListening -CheckPort $Port) -and $elapsed -lt $WaitSeconds) {
    Start-Sleep -Seconds 2
    $elapsed += 2
  }
}

# 2) Health check
Write-Host "`n# GET /api/health" -ForegroundColor Yellow
$healthUrl = "$Base/api/health"
$healthOk = $false
try {
  $health = Invoke-RestMethod -Uri $healthUrl -Method Get
  $health | Format-List
  if ($health.ok) { $healthOk = $true }
} catch {
  Write-Host "health failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 3) Seed admin
$prevEmail = $env:ADMIN_EMAIL
$prevPassword = $env:ADMIN_PASSWORD
$env:ADMIN_EMAIL = $AdminEmail
$env:ADMIN_PASSWORD = $AdminPassword

Write-Host "`n# seed admin" -ForegroundColor Yellow
Push-Location $BackendRoot
try {
  npm run seed:admin
} catch {
  Write-Host "seed:admin failed: $($_.Exception.Message)" -ForegroundColor Red
} finally {
  Pop-Location
  $env:ADMIN_EMAIL = $prevEmail
  $env:ADMIN_PASSWORD = $prevPassword
}

# 4) Login
Write-Host "`n# POST /api/admin/auth/login" -ForegroundColor Yellow
$loginUrl = "$Base/api/admin/auth/login"
$loginBody = @{ email = $AdminEmail; password = $AdminPassword } | ConvertTo-Json
$token = $null
try {
  $login = Invoke-RestMethod -Uri $loginUrl -Method Post -ContentType "application/json" `
    -Headers @{ "x-tenant" = $Tenant } -Body $loginBody
  $token = $login.token
  if ($token) {
    Write-Host "token: $token" -ForegroundColor Green
  } else {
    Write-Host "token not found in response" -ForegroundColor Yellow
  }
} catch {
  Write-Host "login failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 5) List bots (if token)
Write-Host "`n# GET /api/admin/bots" -ForegroundColor Yellow
if ($token) {
  try {
    $bots = Invoke-RestMethod -Uri "$Base/api/admin/bots" -Method Get -Headers @{
      Authorization = "Bearer $token"
      "x-tenant"    = $Tenant
    }
    $items = @($bots.items)
    $count = $items.Count
    Write-Host "bots: $count item(s)" -ForegroundColor Green
    if ($count -gt 0) {
      $items | Select-Object -First 5 id,name,platform | Format-Table
    }
  } catch {
    Write-Host "bots failed: $($_.Exception.Message)" -ForegroundColor Red
  }
} else {
  Write-Host "skip bots: no token" -ForegroundColor Yellow
}

Write-Host "`nDone. healthOk=$healthOk" -ForegroundColor DarkCyan
