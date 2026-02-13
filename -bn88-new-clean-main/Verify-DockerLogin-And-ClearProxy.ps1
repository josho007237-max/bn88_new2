if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw 'PowerShell 5.1+ required.'
}

function Run-DockerCommand {
    param (
        [string]$Label,
        [string]$Command
    )

    Write-Output "`n--- $Label ---"
    Write-Output "Executing: $Command"
    Invoke-Expression $Command
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "$Command exited with $LASTEXITCODE"
    }
}

function Show-FilteredInfo {
    param (
        [string]$Title,
        [string]$Command,
        [string]$Pattern
    )

    Write-Output "`n$Title"
    $lines = Invoke-Expression $Command 2>&1 | Where-Object { $_ -match $Pattern }
    if ($lines) {
        $lines
    } else {
        Write-Output '  (none)'
    }
}

$dockerDesktopExe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'

Run-DockerCommand -Label 'Step 1: Pull hello-world' -Command 'docker pull hello-world'
Run-DockerCommand -Label 'Step 1: Run hello-world' -Command 'docker run --rm hello-world'

Show-FilteredInfo -Title 'Step 2: docker system info (Username only)' -Command 'docker system info' -Pattern '^Username'
Show-FilteredInfo -Title 'Step 3: docker info (Proxy settings)' -Command 'docker info' -Pattern '^(HTTP|HTTPS|No) Proxy'

$proxyLines = docker info 2>&1 | Where-Object { $_ -match '^(HTTP|HTTPS|No) Proxy' }
$proxyHasContainer = $proxyLines -match 'http\.docker\.internal:3128'

if ($proxyHasContainer) {
    Write-Warning "`nhttp.docker.internal:3128 detected; clearing Docker Desktop proxy settings."
    Run-DockerCommand -Label 'Step 4a: Check WSL docker-desktop env' -Command "wsl -d docker-desktop sh -lc 'env | grep -i proxy || true'"
    Run-DockerCommand -Label 'Step 4b: Shutdown docker-desktop WSL' -Command 'wsl --shutdown'

    if (Test-Path $dockerDesktopExe) {
        Write-Output "`nStep 4c: Restart Docker Desktop ($dockerDesktopExe)"
        Start-Process -FilePath $dockerDesktopExe
    } else {
        Write-Warning "Docker Desktop executable not found at $dockerDesktopExe"
    }
}

Show-FilteredInfo -Title 'Step 5: docker info (verify proxies cleared)' -Command 'docker info' -Pattern '^(HTTP|HTTPS|No) Proxy'
