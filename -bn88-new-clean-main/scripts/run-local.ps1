param(
  [string]$BaseUrl = 'http://127.0.0.1:3000',
  [string]$FrontendUrl = 'http://127.0.0.1:5555',
  [string]$Tenant = 'bn9',
  [string]$Email = 'root@bn9.local',
  [string]$Password = 'bn9@12345',
  [int]$BackendPort = 3000,
  [int]$FrontendPort = 5555
)

$ErrorActionPreference = 'Stop'

function Info([string]$Message) {
  Write-Host "[run-local] $Message" -ForegroundColor Cyan
}

function Warn([string]$Message) {
  Write-Host "[run-local] WARN: $Message" -ForegroundColor Yellow
}

function Fail([string]$Message) {
  Write-Host "[run-local] ERROR: $Message" -ForegroundColor Red
  exit 1
}

function Show-PortOwners([int]$Port) {
  try {
    $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
    if (-not $conns) { return }

    Write-Host "[run-local] Port $Port is in use:" -ForegroundColor Yellow
    foreach ($conn in $conns) {
      $pid = $conn.OwningProcess
      $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $pid" -ErrorAction SilentlyContinue
      [pscustomobject]@{
        Port = $Port
        PID = $pid
        ProcessName = $proc.Name
        CommandLine = $proc.CommandLine
      } | Format-List
    }
  } catch {
    Warn "cannot inspect port $Port via Get-NetTCPConnection: $($_.Exception.Message)"
  }
}

function Ensure-PortFree([int]$Port) {
  try {
    $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
    if ($conns) {
      Show-PortOwners -Port $Port
      Fail "port $Port is in use; stop the process and retry"
    }
  } catch {
    if ($_.Exception.Message -match 'No matching MSFT_NetTCPConnection objects found') { return }
    Warn "cannot validate port $Port availability: $($_.Exception.Message)"
  }
}

function Wait-Http([string]$Url, [int]$TimeoutSec = 60) {
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    try {
      Invoke-RestMethod -Method Get -Uri $Url | Out-Null
      return $true
    } catch {
      Start-Sleep -Milliseconds 800
    }
  }
  return $false
}

function Ensure-FrontendDeps([string]$FrontendDir) {
  $viteCmdPath = Join-Path $FrontendDir 'node_modules/.bin/vite.cmd'
  if (-not (Test-Path $viteCmdPath)) {
    $lockFile = Join-Path $FrontendDir 'package-lock.json'
    Push-Location $FrontendDir
    try {
      if (Test-Path $lockFile) {
        Info 'frontend vite missing; run npm ci'
        & npm ci
      } else {
        Info 'frontend vite missing; run npm install'
        & npm install
      }
      if ($LASTEXITCODE -ne 0) {
        throw "frontend dependency install failed with exit code $LASTEXITCODE"
      }
    } finally {
      Pop-Location
    }
  }

  Push-Location $FrontendDir
  try {
    & npx vite --version | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail 'frontend deps missing: vite' }
  } catch {
    Fail 'frontend deps missing: vite'
  } finally {
    Pop-Location
  }
}

function Ensure-BackendDeps([string]$BackendDir) {
  $nodeModulesDir = Join-Path $BackendDir 'node_modules'
  if (-not (Test-Path $nodeModulesDir)) {
    Fail "backend dependencies missing at $nodeModulesDir`nRun:`n  cd $BackendDir`n  npm ci"
  }
}

function Invoke-BackendMigrateDeploy([string]$BackendDir) {
  Info 'run prisma migrate deploy'

  $devDbPath = Join-Path $BackendDir 'dev.db'
  $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

  Push-Location $BackendDir
  try {
    try {
      & npm run migrate:deploy
      if ($LASTEXITCODE -eq 0) { return }
      throw "npm run migrate:deploy exit code $LASTEXITCODE"
    } catch {
      $errorText = $_ | Out-String
      if ($errorText -notmatch 'P3009') { throw }

      Warn 'detected Prisma P3009; backing up and removing bn88-backend-v12/dev.db before retry'
      if (Test-Path $devDbPath) {
        $backupPath = Join-Path $BackendDir ("dev.db.bak.$timestamp")
        Copy-Item -Path $devDbPath -Destination $backupPath -Force
        Remove-Item -Path $devDbPath -Force
        Info "database backup created: $backupPath"
      } else {
        Warn "database file not found at $devDbPath"
      }

      Info 'retry prisma migrate deploy after database reset'
      & npm run migrate:deploy
      if ($LASTEXITCODE -ne 0) {
        throw "retry npm run migrate:deploy exit code $LASTEXITCODE"
      }
    }
  } finally {
    Pop-Location
  }
}

$repoRoot = (Resolve-Path (Split-Path -Parent $PSScriptRoot)).Path
Info "repoRoot: $repoRoot"

$currentDir = (Get-Location).Path
if ($currentDir -ne $repoRoot) {
  Info "current directory is '$currentDir' -> cd to repoRoot"
  Set-Location $repoRoot
}

$backendDir = Join-Path $repoRoot 'bn88-backend-v12'
$frontendDir = Join-Path $repoRoot 'bn88-frontend-dashboard-v12'

if (-not (Test-Path $backendDir)) { Fail "missing backend dir: $backendDir" }
if (-not (Test-Path $frontendDir)) { Fail "missing frontend dir: $frontendDir" }

Ensure-BackendDeps -BackendDir $backendDir
Invoke-BackendMigrateDeploy -BackendDir $backendDir

$pwshCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } elseif (Get-Command powershell -ErrorAction SilentlyContinue) { 'powershell' } else { $null }
if (-not $pwshCmd) { Fail 'cannot find pwsh/powershell in PATH' }

Info 'kill stale node processes'
Get-Process -Name node -ErrorAction SilentlyContinue | ForEach-Object {
  try { Stop-Process -Id $_.Id -Force -ErrorAction Stop } catch { }
}

Show-PortOwners -Port $BackendPort
Show-PortOwners -Port $FrontendPort

Ensure-PortFree -Port $BackendPort

Info 'start backend with DEBUG_AUTH=1'
$backendCmd = "$env:DEBUG_AUTH='1'; $env:PORT='$BackendPort'; npm run dev"
Start-Process -FilePath $pwshCmd -WorkingDirectory $backendDir -ArgumentList '-NoExit', '-Command', $backendCmd | Out-Null

if (-not (Wait-Http -Url "$BaseUrl/api/health" -TimeoutSec 90)) {
  Show-PortOwners -Port $BackendPort
  Fail "backend not ready at $BaseUrl/api/health`nExpected backend path: $backendDir`nTry:`n  cd $backendDir`n  $env:PORT=$BackendPort`n  npm run dev"
}

Ensure-FrontendDeps -FrontendDir $frontendDir

Info 'start frontend'
Start-Process -FilePath $pwshCmd -WorkingDirectory $frontendDir -ArgumentList '-NoExit', '-Command', 'npm run dev -- --host 0.0.0.0 --port 5555' | Out-Null

if (-not (Wait-Http -Url $FrontendUrl -TimeoutSec 60)) {
  Show-PortOwners -Port $FrontendPort
  Warn "frontend not ready at $FrontendUrl (continuing API smoke tests)"
}

Info 'test /api/health'
$health = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/health"
if ($null -eq $health) { Fail 'health response is null' }

Info 'test login'
$loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress
$login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/admin/auth/login" -ContentType 'application/json' -Body $loginBody
$token = $login.token
if ([string]::IsNullOrWhiteSpace($token)) { Fail 'login did not return token' }

$headers = @{ Authorization = "Bearer $token"; 'x-tenant' = $Tenant }

Info 'test /api/admin/bots'
$bots = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/bots" -Headers $headers
if ($bots.ok -ne $true) { Fail "bots.ok expected true, got '$($bots.ok)'" }
if (-not $bots.items -or $bots.items.Count -lt 1) { Fail 'bots list is empty; cannot test /secrets' }

$botId = $bots.items[0].id
if ([string]::IsNullOrWhiteSpace($botId)) { Fail 'first bot id is empty' }

Info "test /api/admin/bots/$botId/secrets"
$secrets = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/bots/$botId/secrets" -Headers $headers
if ($secrets.ok -ne $true) { Fail "secrets.ok expected true, got '$($secrets.ok)'" }

Write-Host ''
Write-Host '[run-local] all checks passed' -ForegroundColor Green
Write-Host "[run-local] backend: $BaseUrl/api/health"
Write-Host "[run-local] frontend: $FrontendUrl"
