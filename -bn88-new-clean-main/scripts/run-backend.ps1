param(
  [string]$Root = 'C:\Go23_th\bn88_new2\-bn88-new-clean-main'
)

$ErrorActionPreference = 'Stop'

function Test-PortListening([int]$Port) {
  try {
    $conn = Get-NetTCPConnection -LocalAddress '127.0.0.1' -LocalPort $Port -State Listen -ErrorAction Stop
    return ($null -ne $conn)
  } catch {
    if ($_.Exception.Message -match 'No matching MSFT_NetTCPConnection objects found') {
      return $false
    }
    return $false
  }
}

if ([string]::IsNullOrWhiteSpace($Root)) {
  throw 'Root ว่างเปล่า; กรุณาระบุ -Root <path>'
}

if (-not (Test-Path $Root)) {
  throw "ไม่พบ Root: $Root"
}

$backendDir = Join-Path $Root 'bn88-backend-v12'
$packageJson = Join-Path $backendDir 'package.json'

if (-not (Test-Path $packageJson)) {
  throw "ไม่พบไฟล์ backend package.json: $packageJson"
}

Write-Host "ROOT: $Root"
Write-Host "PWD: $(Get-Location)"
Write-Host "Port 3000 listening: $(Test-PortListening -Port 3000)"
Write-Host "Port 6380 listening: $(Test-PortListening -Port 6380)"

$redisReady = Test-NetConnection -ComputerName '127.0.0.1' -Port 6380 -WarningAction SilentlyContinue -InformationLevel Quiet
if (-not $redisReady) {
  Write-Host 'Redis at 127.0.0.1:6380 not ready -> ensure docker container bn88-redis'

  $running = (docker ps --filter "name=^/bn88-redis$" --format "{{.Names}}" 2>$null)
  if ($running -match '^bn88-redis$') {
    Write-Host 'bn88-redis already running'
  } else {
    $exists = (docker ps -a --filter "name=^/bn88-redis$" --format "{{.Names}}" 2>$null)
    if ($exists -match '^bn88-redis$') {
      docker start bn88-redis | Out-Null
      Write-Host 'started existing bn88-redis'
    } else {
      docker run -d --name bn88-redis -p 6380:6379 redis:7-alpine | Out-Null
      Write-Host 'created and started bn88-redis'
    }
  }
}

Set-Location $backendDir

npm ci
if ($LASTEXITCODE -ne 0) { throw 'npm ci failed' }

npx prisma generate
if ($LASTEXITCODE -ne 0) { throw 'prisma generate failed' }

npx prisma db push
if ($LASTEXITCODE -ne 0) { throw 'prisma db push failed' }

Write-Host ''
Write-Host 'Quick test commands:'
Write-Host '  curl http://127.0.0.1:3000/api/health'
Write-Host '  $body = @{ email = "root@bn9.local"; password = "bn9@12345" } | ConvertTo-Json'
Write-Host '  $login = irm -Method Post -Uri "http://127.0.0.1:3000/api/admin/auth/login" -ContentType "application/json" -Body $body'
Write-Host '  $token = $login.token'
Write-Host '  irm -Method Get -Uri "http://127.0.0.1:3000/api/admin/chat/sessions?limit=20" -Headers @{ Authorization = "Bearer $token"; "x-tenant" = "bn9" }'
Write-Host ''

npm run dev
if ($LASTEXITCODE -ne 0) { throw 'npm run dev failed' }
