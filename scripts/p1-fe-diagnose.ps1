$ErrorActionPreference = 'Stop'

Write-Host '[p1-fe-diagnose] npm ping'
npm ping

Write-Host ''
Write-Host '[p1-fe-diagnose] curl -I https://registry.npmjs.org/vite'
curl.exe -I https://registry.npmjs.org/vite

Write-Host ''
Write-Host '[p1-fe-diagnose] npm config (registry/proxy)'
npm config get registry
npm config get proxy
npm config get https-proxy

Write-Host ''
Write-Host '[p1-fe-diagnose] latest npm log (last 80 lines)'
$logRoot = Join-Path $env:APPDATA 'npm-cache\_logs'
$latestLog = Get-ChildItem -LiteralPath $logRoot -File -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
if ($latestLog) {
  Write-Host "[p1-fe-diagnose] latest log: $($latestLog.FullName)"
  Get-Content -LiteralPath $latestLog.FullName -Tail 80
} else {
  Write-Host '[p1-fe-diagnose] no npm log found under %APPDATA%\npm-cache\_logs' -ForegroundColor Yellow
}
