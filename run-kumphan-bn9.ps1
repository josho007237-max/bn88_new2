$ErrorActionPreference = "Stop"

$uuid = "c14cb54b-430a-4ec1-8446-deb610517849"
$cloudflaredDir = Join-Path $env:USERPROFILE ".cloudflared"
$configPath = Join-Path $cloudflaredDir "config.yml"
$credentialsPath = Join-Path $cloudflaredDir "$uuid.json"

if (-not (Test-Path $cloudflaredDir)) {
    New-Item -ItemType Directory -Path $cloudflaredDir -Force | Out-Null
}

$configContent = @"
tunnel: $uuid
credentials-file: $credentialsPath
ingress:
  - hostname: api.bn9.app
    service: http://127.0.0.1:3000
  - hostname: admin.bn9.app
    service: http://127.0.0.1:5555
  - service: http_status:404
"@

Set-Content -Path $configPath -Value $configContent -Encoding UTF8

if (-not (Test-Path $credentialsPath)) {
    Write-Error "ไม่พบไฟล์ credentials: $credentialsPath"
    exit 1
}

Write-Host "Starting tunnel with config: $configPath"
cloudflared --loglevel debug tunnel --config $configPath run $uuid

Write-Host ""
Write-Host "ตรวจสอบสถานะหลังรันด้วยคำสั่ง:"
Write-Host "cloudflared tunnel info $uuid"
Write-Host ""
Write-Host "ทดสอบจาก Windows (กรณีเจอ CRYPT_E_NO_REVOCATION_CHECK):"
Write-Host "curl.exe -i --ssl-no-revoke https://api.bn9.app/api/health"
Write-Host "curl.exe -i -k https://api.bn9.app/api/health"
Write-Host "irm https://api.bn9.app/api/health -SkipCertificateCheck"
