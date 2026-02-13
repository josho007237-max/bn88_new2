# Requires PowerShell 7+ (pwsh) for restart via -Verb RunAs
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = "-NoProfile","-ExecutionPolicy","Bypass","-File",$PSCommandPath
    Start-Process pwsh -Verb RunAs -ArgumentList $args
    exit 1
}

$serviceName = 'com.docker.service'
sc.exe config $serviceName start= auto | Out-Null
sc.exe start $serviceName | Out-Null
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq 'Running') {
    Write-Output "Service $serviceName is RUNNING"
} else {
    Write-Output "Service $serviceName FAILED"
}

$paths = [ordered]@{
    "SettingsStore" = Join-Path $env:APPDATA 'Docker\settings-store.json'
    "LocalDockerDir" = Join-Path $env:LOCALAPPDATA 'Docker'
    "UserDockerConfig" = Join-Path $env:USERPROFILE '.docker\config.json'
}

foreach ($entry in $paths.GetEnumerator()) {
    $message = Test-Path $entry.Value ? 'exists' : 'missing'
    Write-Output "$($entry.Key): $($entry.Value) ($message)"
}

if (Test-Path $paths.SettingsStore) {
    $backup = "$($paths.SettingsStore).bak"
    Copy-Item $paths.SettingsStore $backup -Force
    Remove-Item $paths.SettingsStore -Force
    Write-Output "Settings reset: backed up to $backup and removed original. Images/containers untouched."
} else {
    Write-Output "No settings-store.json to reset."
}

$desktopExe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
if (Test-Path $desktopExe) {
    Start-Process -FilePath $desktopExe
    Write-Output 'Docker Desktop launched.'
} else {
    Write-Warning "Unable to find Docker Desktop executable at $desktopExe"
}

Write-Output 'Please verify Settings > Resources > Proxies is disabled before reconnecting your workloads.'
