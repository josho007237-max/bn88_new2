param(
  [string]$BaseUrl = "http://127.0.0.1:3000",
  [string]$Tenant = "bn9",
  [Parameter(Mandatory = $true)][string]$Token,
  [int]$MaxTimeSec = 10
)

$ErrorActionPreference = "Stop"

$url = "$BaseUrl/api/live/$Tenant?token=$([uri]::EscapeDataString($Token))"
Write-Host "[smoke_sse] GET $url"
Write-Host "[smoke_sse] ALLOW_SSE_QUERY_TOKEN ต้องเป็น 1"

curl.exe -N "$url" -H "Accept: text/event-stream" --max-time $MaxTimeSec
