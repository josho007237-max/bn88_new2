$ErrorActionPreference = "Stop"

$tunnelUuid = $env:TUNNEL_UUID
$domainApi = $env:DOMAIN_API
$domainAdmin = $env:DOMAIN_ADMIN
$tunnelName = if ([string]::IsNullOrWhiteSpace($env:TUNNEL_NAME)) { $tunnelUuid } else { $env:TUNNEL_NAME }

if ([string]::IsNullOrWhiteSpace($tunnelUuid)) {
    throw "Missing env var: TUNNEL_UUID"
}
if ([string]::IsNullOrWhiteSpace($domainApi)) {
    throw "Missing env var: DOMAIN_API"
}
if ([string]::IsNullOrWhiteSpace($domainAdmin)) {
    throw "Missing env var: DOMAIN_ADMIN"
}

$cloudflaredDir = Join-Path $env:USERPROFILE ".cloudflared"
$configPath = Join-Path $cloudflaredDir "config.yml"
$credentialsPath = Join-Path $cloudflaredDir "$tunnelUuid.json"

New-Item -ItemType Directory -Force -Path $cloudflaredDir | Out-Null

$configYaml = @"
tunnel: $tunnelUuid
credentials-file: $credentialsPath

ingress:
  - hostname: $domainApi
    service: http://127.0.0.1:3000
  - hostname: $domainAdmin
    service: http://127.0.0.1:5555
  - service: http_status:404
"@

Set-Content -Path $configPath -Value $configYaml -Encoding utf8

Write-Host "Wrote config: $configPath"
Write-Host ""
Write-Host "Validating ingress..."
cloudflared tunnel ingress validate --config "$configPath"

Write-Host ""
Write-Host "Run tunnel (foreground):"
Write-Host "cloudflared tunnel --config `"$configPath`" run $tunnelName"
cloudflared tunnel --config "$configPath" run $tunnelName

Write-Host ""
Write-Host "DNS check commands:"
Write-Host "Resolve-DnsName $domainApi -Type CNAME"
Write-Host "Resolve-DnsName $domainAdmin -Type CNAME"

Write-Host ""
Write-Host "Test commands:"
Write-Host "curl https://$domainApi/api/health"
Write-Host "curl -I https://$domainAdmin"
