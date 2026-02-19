param(
  [string]$Domain = "api.bn9.app",
  [string]$TunnelName = "bn88-api",
  [string]$LocalHealthUrl = "http://127.0.0.1:3000/api/health"
)

$ErrorActionPreference = "Stop"

$script:FailCount = 0

function Write-CheckResult {
  param(
    [string]$Title,
    [bool]$Ok,
    [string]$Detail = ""
  )

  if ($Ok) {
    Write-Host "[PASS] $Title" -ForegroundColor Green
  } else {
    Write-Host "[FAIL] $Title" -ForegroundColor Red
    $script:FailCount++
  }

  if ($Detail) {
    Write-Host "       $Detail" -ForegroundColor DarkGray
  }
}

Write-Host "=== SMOKE DOMAIN (Cloudflare Tunnel + DNS + Health) ===" -ForegroundColor Cyan
Write-Host "Domain: $Domain | Tunnel: $TunnelName" -ForegroundColor DarkCyan

# 1) Local health
try {
  $localOut = & curl.exe -sS -o NUL -w "%{http_code}" --max-time 5 "$LocalHealthUrl" 2>&1
  $ok = ($LASTEXITCODE -eq 0 -and "$localOut" -eq "200")
  Write-CheckResult "Local health $LocalHealthUrl" $ok "status=$localOut"
} catch {
  Write-CheckResult "Local health $LocalHealthUrl" $false $_.Exception.Message
}

# 2) DNS resolve
try {
  $dnsOut = Resolve-DnsName $Domain -Type CNAME -ErrorAction Stop | Select-Object -First 1
  $dnsTarget = if ($dnsOut.NameHost) { $dnsOut.NameHost } elseif ($dnsOut.QueryName) { $dnsOut.QueryName } else { "resolved" }
  Write-CheckResult "DNS Resolve-DnsName $Domain" $true $dnsTarget
} catch {
  Write-CheckResult "DNS Resolve-DnsName $Domain" $false $_.Exception.Message
}

# 3) tunnel route dns list
try {
  $routeOut = & cloudflared tunnel route dns list 2>&1
  $ok = ($LASTEXITCODE -eq 0 -and ($routeOut | Out-String) -match [regex]::Escape($Domain))
  Write-CheckResult "cloudflared tunnel route dns list" $ok (($routeOut | Select-Object -First 3) -join " | ")
} catch {
  Write-CheckResult "cloudflared tunnel route dns list" $false $_.Exception.Message
}

# 4) tunnel info
try {
  $infoOut = & cloudflared tunnel info $TunnelName 2>&1
  $text = $infoOut | Out-String
  $ok = ($LASTEXITCODE -eq 0 -and ($text -match "connector" -or $text -match "active"))
  Write-CheckResult "cloudflared tunnel info $TunnelName" $ok (($infoOut | Select-Object -First 5) -join " | ")
} catch {
  Write-CheckResult "cloudflared tunnel info $TunnelName" $false $_.Exception.Message
}

# 5) domain health (Windows schannel friendly)
$domainHealthUrl = "https://$Domain/api/health"
try {
  $domainOut = & curl.exe -sS -o NUL -w "%{http_code}" --max-time 10 --ssl-no-revoke "$domainHealthUrl" 2>&1
  $ok = ($LASTEXITCODE -eq 0 -and "$domainOut" -eq "200")
  Write-CheckResult "Domain health $domainHealthUrl" $ok "status=$domainOut"
} catch {
  Write-CheckResult "Domain health $domainHealthUrl" $false $_.Exception.Message
}

Write-Host ""
if ($script:FailCount -eq 0) {
  Write-Host "SMOKE RESULT: PASS ✅" -ForegroundColor Green
  exit 0
}

Write-Host "SMOKE RESULT: FAIL ❌ ($script:FailCount checks failed)" -ForegroundColor Red
exit 1
