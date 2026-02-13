param()

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$settingsStore = Join-Path $env:APPDATA 'Docker\settings-store.json'
$backupTarget = "$settingsStore.bak_$timestamp"

Write-Host '=== docker info proxy lines (before cleanup) ==='
docker info 2>&1 | Select-String -Pattern 'proxy' || Write-Host 'docker info failed or produced no proxy lines'

Write-Host '=== Env:*proxy* ==='
Get-ChildItem Env:*proxy* | Sort-Object Name

Write-Host 'Stopping Docker Desktop and WSL...'
Stop-Process -Name 'Docker Desktop' -ErrorAction SilentlyContinue
wsl --shutdown

Write-Host "Settings store path: $settingsStore"
Write-Host "Test-Path before removal: $(Test-Path $settingsStore)"
if (Test-Path $settingsStore) {
    Copy-Item -Path $settingsStore -Destination $backupTarget -Force
    Remove-Item -Path $settingsStore -Force
    Write-Host "Backed up settings-store.json to $backupTarget and removed the original."
} else {
    Write-Host 'settings-store.json not found; skipping backup/removal.'
}

$dockerExe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
if (Test-Path $dockerExe) {
    Start-Process -FilePath $dockerExe
    Write-Host 'Started Docker Desktop; waiting for docker info to respond (max 30 retries)...'
    $retry = 0
    while ($retry -lt 30) {
        try {
            docker info | Out-Null
            Write-Host 'docker info is now responsive.'
            break
        } catch {
            Start-Sleep -Seconds 2
            $retry++
        }
    }
    if ($retry -ge 30) {
        Write-Host 'Timed out waiting for docker info to respond.'
    }
} else {
    Write-Host 'Docker Desktop executable missing; please start it manually.'
}

Write-Host '=== docker info proxy lines (after restart) ==='
docker info 2>&1 | Select-String -Pattern 'proxy' || Write-Host 'docker info failed or produced no proxy lines'

$found3128 = $false
$dockerJsonPaths = @(
    Join-Path $env:APPDATA 'Docker',
    Join-Path $env:LOCALAPPDATA 'Docker'
)
$proxyPattern = '3128'
foreach ($root in $dockerJsonPaths) {
    if (Test-Path $root) {
        Get-ChildItem -Path $root -Filter '*.json' -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            if (Select-String -Path $_.FullName -Pattern $proxyPattern -Quiet) {
                Write-Host "Found 3128 in $($_.FullName)"
                $found3128 = $true
            }
        }
    }
}
$testUrl = 'https://hub.docker.com/auth/desktop/redirect'
$testResult = 'FAIL'
$testDetails = 'no response'
try {
    $response = Invoke-WebRequest $testUrl -MaximumRedirection 0 -ErrorAction Stop
    $code = [int]$response.StatusCode
    $testDetails = "status $code"
    if ($code -ge 200 -and $code -lt 400) {
        $testResult = 'PASS'
    }
} catch {
    $resp = $_.Exception.Response
    if ($resp) {
        $code = [int]$resp.StatusCode
        $testDetails = "status $code"
        if ($code -ge 200 -and $code -lt 400) {
            $testResult = 'PASS'
        }
    } else {
        $testDetails = $_.Exception.Message
    }
}
Write-Host "Invoke-WebRequest $testUrl - summary: $testResult ($testDetails)"

$proxyRemoved = -not $found3128
$redirectReachable = $testResult -eq 'PASS'
Write-Host "Final summary: proxy_removed=$proxyRemoved, redirect_reachable=$redirectReachable"
