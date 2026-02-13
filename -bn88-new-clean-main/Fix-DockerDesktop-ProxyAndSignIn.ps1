$proxyLines = docker info 2>&1 | Where-Object { $_ -match '^(HTTP|HTTPS|No) Proxy' }
if ($proxyLines) {
    $proxyLines | ForEach-Object { Write-Output $_ }
} else {
    Write-Output 'No proxy info reported by docker info.'
}

if ($proxyLines -match 'http\.docker\.internal:3128') {
    Write-Warning 'http.docker.internal:3128 detected. Disable it via Docker Desktop > Settings > Resources > Proxies.'
}

$registryPath = 'C:\ProgramData\DockerDesktop\registry.json'
$registryState = Test-Path $registryPath
Write-Output "Registry policy file $registryPath is $($registryState ? 'present' : 'missing')."

$orgPolicyCmd = 'reg query "HKLM\SOFTWARE\Policies\Docker\Docker Desktop" /v allowedOrgs'
$orgPolicyResult = iex $orgPolicyCmd 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Output $orgPolicyResult
} else {
    Write-Output 'Policy allowedOrgs either missing or inaccessible.'
}

$redirectPathStatus = 'Unknown'
try {
    $resp = Invoke-WebRequest -Uri 'https://hub.docker.com/auth/desktop/redirect' -MaximumRedirection 0 -ErrorAction Stop
    $redirectPathStatus = 'redirect path OK'
} catch [System.Net.WebException] {
    $httpResp = $_.Exception.Response
    if ($httpResp -and $httpResp.StatusCode -ge 300 -and $httpResp.StatusCode -lt 400) {
        $redirectPathStatus = 'redirect path OK'
    } else {
        $redirectPathStatus = 'โดน reset'
    }
} catch {
    $redirectPathStatus = "Unable to reach hub: $($_.Exception.Message)"
}

Write-Output "Redirect test summary: $redirectPathStatus"
Write-Output 'สรุป: ต้องแก้ proxy หรือโดน org policy.'
Write-Output 'Next steps:'
Write-Output '1. เปิด Docker Desktop > Settings > Resources > Proxies เพื่อยืนยัน proxy ทั้งหมดปิด.'
Write-Output '2. หากล็อคโดย policy ให้ตรวจ `HKLM:\SOFTWARE\Policies\Docker\Docker Desktop` ว่ามี allowedOrgs ที่ถูกต้อง.'
Write-Output '3. รีสตาร์ท Docker Desktop หลังจัดการ proxy/policy เพื่อดูว่าการเชื่อมต่อ hub ไม่ถูกบล็อก.'
