param(
  [string]$Root = 'C:\BN88\BN88-new-clean'
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Step, [string]$Message) {
  Write-Host "[$Step] $Message" -ForegroundColor Cyan
}

function Write-Pass([string]$Step, [string]$Message) {
  Write-Host "[$Step] PASS: $Message" -ForegroundColor Green
}

function Write-Fail([string]$Step, [string]$Message) {
  Write-Host "[$Step] FAIL: $Message" -ForegroundColor Red
  exit 1
}

function Stop-PortOwners([int[]]$Ports) {
  foreach ($port in $Ports) {
    try {
      $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction Stop
    } catch {
      if ($_.Exception.Message -match 'No matching MSFT_NetTCPConnection objects found') {
        Write-Pass 'STEP1' "port $port is already free"
        continue
      }
      Write-Fail 'STEP1' "cannot inspect port $port: $($_.Exception.Message)"
    }

    if (-not $conns) {
      Write-Pass 'STEP1' "port $port is already free"
      continue
    }

    $pids = $conns | Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($pid in $pids) {
      try {
        Stop-Process -Id $pid -Force -ErrorAction Stop
        Write-Step 'STEP1' "stopped PID $pid on port $port"
      } catch {
        Write-Fail 'STEP1' "failed to stop PID $pid on port $port: $($_.Exception.Message)"
      }
    }

    Start-Sleep -Milliseconds 300
    try {
      $left = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction Stop
      if ($left) {
        Write-Fail 'STEP1' "port $port is still occupied"
      }
      Write-Pass 'STEP1' "port $port released"
    } catch {
      if ($_.Exception.Message -match 'No matching MSFT_NetTCPConnection objects found') {
        Write-Pass 'STEP1' "port $port released"
      } else {
        Write-Fail 'STEP1' "cannot re-check port $port: $($_.Exception.Message)"
      }
    }
  }
}

Write-Step 'INIT' "Root = $Root"
if (-not (Test-Path $Root)) {
  Write-Fail 'INIT' "root not found: $Root"
}

$backendDir = Join-Path $Root 'bn88-backend-v12'
$frontendDir = Join-Path $Root 'bn88-frontend-dashboard-v12'
if (-not (Test-Path $backendDir)) { Write-Fail 'INIT' "backend dir not found: $backendDir" }
if (-not (Test-Path $frontendDir)) { Write-Fail 'INIT' "frontend dir not found: $frontendDir" }
Write-Pass 'INIT' 'project directories found'

Write-Step 'STEP1' 'kill listeners on 3000/5555/6380'
Stop-PortOwners -Ports @(3000, 5555, 6380)

Write-Step 'STEP2' 'ensure redis container bn88-redis (6380:6379)'
try {
  $running = (docker ps --filter "name=^/bn88-redis$" --format "{{.Names}}" 2>$null)
  if ($running -match '^bn88-redis$') {
    Write-Pass 'STEP2' 'bn88-redis is already running'
  } else {
    $exists = (docker ps -a --filter "name=^/bn88-redis$" --format "{{.Names}}" 2>$null)
    if ($exists -match '^bn88-redis$') {
      docker start bn88-redis | Out-Null
      Write-Pass 'STEP2' 'started existing bn88-redis container'
    } else {
      docker run -d --name bn88-redis -p 6380:6379 redis:7-alpine | Out-Null
      Write-Pass 'STEP2' 'created and started bn88-redis container'
    }
  }
} catch {
  Write-Fail 'STEP2' "docker/redis failed: $($_.Exception.Message)"
}

$pwshCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } elseif (Get-Command powershell -ErrorAction SilentlyContinue) { 'powershell' } else { $null }
if (-not $pwshCmd) {
  Write-Fail 'INIT' 'cannot find pwsh/powershell in PATH'
}

Write-Step 'STEP3' 'backend: npm ci -> prisma generate -> prisma db push'
try {
  Push-Location $backendDir
  npm ci
  if ($LASTEXITCODE -ne 0) { throw 'npm ci failed' }
  npx prisma generate
  if ($LASTEXITCODE -ne 0) { throw 'prisma generate failed' }
  npx prisma db push
  if ($LASTEXITCODE -ne 0) { throw 'prisma db push failed' }
  Write-Pass 'STEP3' 'backend dependency/db prep completed'
} catch {
  Write-Fail 'STEP3' $_
} finally {
  Pop-Location
}

Write-Step 'STEP3' 'start backend npm run dev'
$backendStarted = $false
try {
  Start-Process -FilePath $pwshCmd -WorkingDirectory $backendDir -ArgumentList '-NoExit', '-Command', 'npm run dev' | Out-Null
  $backendStarted = $true
  Write-Pass 'STEP3' 'backend started in new window'
} catch {
  Write-Host "[STEP3] WARN: cannot open new window; run manually:" -ForegroundColor Yellow
  Write-Host "  cd $backendDir" -ForegroundColor Yellow
  Write-Host '  npm run dev' -ForegroundColor Yellow
}

Write-Step 'STEP4' 'dashboard: npm ci -> npm run dev'
try {
  Push-Location $frontendDir
  npm ci
  if ($LASTEXITCODE -ne 0) { throw 'npm ci failed' }
  try {
    Start-Process -FilePath $pwshCmd -WorkingDirectory $frontendDir -ArgumentList '-NoExit', '-Command', 'npm run dev' | Out-Null
    Write-Pass 'STEP4' 'dashboard started in new window'
  } catch {
    Write-Host "[STEP4] WARN: cannot open new window; run manually:" -ForegroundColor Yellow
    Write-Host "  cd $frontendDir" -ForegroundColor Yellow
    Write-Host '  npm run dev' -ForegroundColor Yellow
  }
} catch {
  Write-Fail 'STEP4' $_
} finally {
  Pop-Location
}

Write-Step 'STEP5' 'quick check commands'
Write-Host '  curl http://127.0.0.1:3000/api/health'
Write-Host '  $body = @{ email = "root@bn9.local"; password = "bn9@12345" } | ConvertTo-Json'
Write-Host '  $login = irm -Method Post -Uri "http://127.0.0.1:3000/api/admin/auth/login" -ContentType "application/json" -Body $body'
Write-Host '  $token = $login.token'
Write-Host '  irm -Method Get -Uri "http://127.0.0.1:3000/api/admin/chat/sessions?limit=20" -Headers @{ Authorization = "Bearer $token"; "x-tenant" = "bn9" }'
Write-Pass 'STEP5' 'printed quick check commands'

if ($backendStarted) {
  Write-Pass 'DONE' 'run-full finished (backend/frontend launched)'
} else {
  Write-Pass 'DONE' 'run-full finished (see WARN for manual start commands)'
}
