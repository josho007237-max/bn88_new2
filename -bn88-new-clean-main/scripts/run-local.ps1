param(
  [string]$BaseUrl = 'http://127.0.0.1:3000',
  [string]$FrontendUrl = 'http://127.0.0.1:5555',
  [int]$BackendPort = 3000,
  [int]$FrontendPort = 5555
)

$ErrorActionPreference = 'Stop'

$currentDir = (Get-Location).Path
Info "Current Directory: $currentDir"
$expectedRoot = Split-Path -Parent $PSScriptRoot
$scriptPathFromCwd = Join-Path $currentDir 'scripts/run-local.ps1'
if (-not (Test-Path $scriptPathFromCwd)) {
  Warn "Test-Path scripts/run-local.ps1 = false"
  Warn "please cd to repo root first: $expectedRoot"
}

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
    Warn "cannot inspect port $Port: $($_.Exception.Message)"
  }
}

function Wait-Http([string]$Url, [int]$TimeoutSec = 90) {
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

function Invoke-Npm([string]$Dir, [string]$Command) {
  Push-Location $Dir
  try {
    Info "exec: npm $Command"
    & npm $Command
    if ($LASTEXITCODE -ne 0) {
      Fail "step failed: npm $Command (exit $LASTEXITCODE)"
    }
  } finally {
    Pop-Location
  }
}

function Invoke-PrismaDeployWithP3009Fix([string]$BackendDir) {
  Push-Location $BackendDir
  try {
    Info 'exec: npx prisma migrate deploy'
    $out = & npx prisma migrate deploy 2>&1
    $text = ($out | Out-String)
    if ($LASTEXITCODE -eq 0) {
      Write-Host $text
      return
    }

    if ($text -match 'P3009') {
      Warn 'detected P3009, backup + reset dev.db then retry migrate deploy'
      $dbPath = Join-Path $BackendDir 'prisma/dev.db'
      if (Test-Path $dbPath) {
        $backupDir = Join-Path $BackendDir 'prisma-backup'
        if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupFile = Join-Path $backupDir "dev.db.$stamp.bak"
        Copy-Item -Path $dbPath -Destination $backupFile -Force
        Remove-Item -Path $dbPath -Force
        Info "backed up dev.db to $backupFile and removed dev.db"
      } else {
        Warn "dev.db not found at $dbPath"
      }

      & npx prisma migrate deploy
      if ($LASTEXITCODE -ne 0) {
        Fail 'step failed: prisma migrate deploy after P3009 recovery'
      }
      return
    }

    Write-Host $text
    Fail 'step failed: prisma migrate deploy'
  } finally {
    Pop-Location
  }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$backendDir = Join-Path $repoRoot 'bn88-backend-v12'
$frontendDir = Join-Path $repoRoot 'bn88-frontend-dashboard-v12'

if (-not (Test-Path $backendDir)) { Fail "missing backend dir: $backendDir" }
if (-not (Test-Path $frontendDir)) { Fail "missing frontend dir: $frontendDir" }

$pwshCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } elseif (Get-Command powershell -ErrorAction SilentlyContinue) { 'powershell' } else { $null }
if (-not $pwshCmd) { Fail 'cannot find pwsh/powershell in PATH' }

Info 'kill stale node processes'
Get-Process -Name node -ErrorAction SilentlyContinue | ForEach-Object {
  try { Stop-Process -Id $_.Id -Force -ErrorAction Stop } catch { }
}

Show-PortOwners -Port $BackendPort
Show-PortOwners -Port $FrontendPort

Invoke-Npm -Dir $backendDir -Command 'i'
Push-Location $backendDir
try {
  Info 'exec: npx prisma generate'
  & npx prisma generate
  if ($LASTEXITCODE -ne 0) { Fail 'step failed: prisma generate' }
} finally {
  Pop-Location
}

Invoke-PrismaDeployWithP3009Fix -BackendDir $backendDir
Invoke-Npm -Dir $backendDir -Command 'run seed:dev'
Invoke-Npm -Dir $backendDir -Command 'run seed:admin'

Info 'start backend with DEBUG_AUTH=1'
$backendCmd = '$env:DEBUG_AUTH="1"; npm run dev'
Info "exec: $backendCmd"
Start-Process -FilePath $pwshCmd -WorkingDirectory $backendDir -ArgumentList '-NoExit', '-Command', $backendCmd | Out-Null

if (-not (Wait-Http -Url "$BaseUrl/api/health" -TimeoutSec 120)) {
  Show-PortOwners -Port $BackendPort
  Fail "backend not ready at $BaseUrl/api/health"
}

Invoke-Npm -Dir $frontendDir -Command 'i'
Info 'start frontend'
$frontendCmd = 'npm run dev -- --host 0.0.0.0 --port 5555'
Info "exec: $frontendCmd"
Start-Process -FilePath $pwshCmd -WorkingDirectory $frontendDir -ArgumentList '-NoExit', '-Command', $frontendCmd | Out-Null

if (-not (Wait-Http -Url $FrontendUrl -TimeoutSec 60)) {
  Show-PortOwners -Port $FrontendPort
  Warn "frontend not ready at $FrontendUrl"
}

Info 'check /api/health'
$health = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/health"
if ($null -eq $health) { Fail 'health response is null' }

Write-Host ''
Write-Host '[run-local] ready' -ForegroundColor Green
Write-Host "[run-local] open frontend: $FrontendUrl"
Write-Host "[run-local] backend health: $BaseUrl/api/health"
