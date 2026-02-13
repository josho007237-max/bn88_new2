if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw 'PowerShell 5.1 or later is required.'
}

$dockerDesktopExe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'

Write-Output 'Step 1: Show WSL status'
wsl --status
Write-Output ''
wsl -l -v

Write-Output ''
Write-Output 'Step 2: Restart LxssManager'
Restart-Service LxssManager -Force -ErrorAction SilentlyContinue

Write-Output ''
Write-Output 'Step 3: Restart Docker Desktop process'
Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 3
if (Test-Path $dockerDesktopExe) {
    Start-Process -FilePath $dockerDesktopExe
} else {
    Write-Warning "Unable to locate Docker Desktop executable at $dockerDesktopExe"
}

Write-Output ''
Write-Output 'Checking Docker Desktop startup status'
$dockerVersionOutput = docker version 2>&1
Write-Output $dockerVersionOutput

$startupError = 'Docker Desktop is unable to start'
if ($dockerVersionOutput -match [regex]::Escape($startupError)) {
    Write-Warning "`n$startupError detected; backing up and resetting docker-desktop distributions."

    $backupDir = 'C:\backup'
    New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    wsl --export docker-desktop-data (Join-Path $backupDir 'docker-desktop-data.tar')
    wsl --export docker-desktop (Join-Path $backupDir 'docker-desktop.tar')

    wsl --unregister docker-desktop
    wsl --unregister docker-desktop-data

    if (Test-Path $dockerDesktopExe) {
        Write-Output "`nStep 6: Restarting Docker Desktop after reset"
        Start-Process -FilePath $dockerDesktopExe
    }
}

Write-Output ''
Write-Output 'Step 7: After Docker Desktop boots, go to Settings > Resources > Proxies and turn proxies off if enabled.'
