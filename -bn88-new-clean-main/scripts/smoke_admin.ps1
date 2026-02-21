param(
  [string]$BaseUrl = "http://127.0.0.1:3000",
  [string]$Email = "admin@bn88.local",
  [string]$Password = "Admin1234!"
)

$ErrorActionPreference = "Stop"

$loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json
$login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/admin/login" -ContentType "application/json" -Body $loginBody
if (-not $login.ok -or -not $login.token) { throw "login_failed" }

$headers = @{ Authorization = "Bearer $($login.token)"; "x-tenant" = "bn9" }

$bots = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/bots" -Headers $headers
if (-not $bots.ok -or -not $bots.items -or $bots.items.Count -lt 1) { throw "bots_not_found" }

$botId = $bots.items[0].id
Write-Host "[smoke_admin] botId=$botId"

$sec = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/bots/$botId/secrets" -Headers $headers
if (-not $sec.ok) { throw "secrets_failed" }

Write-Host "[smoke_admin] ok"
$sec | ConvertTo-Json -Depth 5
