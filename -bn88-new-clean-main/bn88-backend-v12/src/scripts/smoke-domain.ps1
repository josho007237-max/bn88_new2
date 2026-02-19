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

function Get-FirstUuid {
  param([string]$Text)
  if (-not $Text) { return $null }
  $m = [regex]::Match($Text, "(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b")
  if ($m.Success) { return $m.Value.ToLower() }
  return $null
}

Write-Host "=== SMOKE DOMAIN (Cloudflare Tunnel + DNS + Health) ===" -ForegroundColor Cyan
Write-Host "Domain: $Domain | Tunnel: $TunnelName" -ForegroundColor DarkCyan

$dnsTarget = $null
$dnsUuid = $null
$tunnelId = $null
$script:RouteFixCommand = $null
$script:DomainHealthStatus = $null

# 1) Local health
try {
  $localOut = & curl.exe -sS -o NUL -w "%{http_code}" --max-time 5 "$LocalHealthUrl" 2>&1
  $ok = ($LASTEXITCODE -eq 0 -and "$localOut" -eq "200")
  Write-CheckResult "Local health $LocalHealthUrl" $ok "status=$localOut"
} catch {
  Write-CheckResult "Local health $LocalHealthUrl" $false $_.Exception.Message
}

# 2) DNS resolve + parse UUID from cfargotunnel target
try {
  $dnsOut = $null
  $dnsRecordKind = ""
  try {
    $dnsOut = Resolve-DnsName $Domain -Type CNAME -Server 1.1.1.1 -ErrorAction Stop
    $dnsRecordKind = "CNAME"
  } catch {
    $dnsOut = Resolve-DnsName $Domain -Server 1.1.1.1 -Type A_AAAA -ErrorAction Stop
    $dnsRecordKind = "A/AAAA"
  }

  $answers = @($dnsOut | Where-Object { $_.Section -eq 'Answer' })
  $ok = ($answers.Count -gt 0)
  $dnsTargetRecord = $answers | Where-Object { $_.NameHost } | Select-Object -First 1
  if (-not $dnsTargetRecord) { $dnsTargetRecord = $answers | Select-Object -First 1 }
  $dnsTarget = if ($dnsTargetRecord.NameHost) { "$($dnsTargetRecord.NameHost)" } elseif ($dnsTargetRecord.Name) { "$($dnsTargetRecord.Name)" } else { "" }
  $dnsUuid = if ($dnsTarget -match "(?i)^(?<id>[0-9a-f-]{36})\.cfargotunnel\.com\.?$") { $Matches['id'].ToLower() } else { Get-FirstUuid $dnsTarget }
  $detail = "answers=$($answers.Count) type=$dnsRecordKind"
  if ($dnsTarget) { $detail = "$detail target=$dnsTarget" }
  if ($dnsUuid) { $detail = "$detail (uuid=$dnsUuid)" }
  Write-CheckResult "DNS Resolve-DnsName $Domain" $ok $detail
} catch {
  Write-CheckResult "DNS Resolve-DnsName $Domain" $false $_.Exception.Message
}

# 3) tunnel route dns list
try {
  $routeOut = & cloudflared tunnel route dns list 2>&1
  $routeText = ($routeOut | Out-String)
  if ($LASTEXITCODE -ne 0) {
    Write-CheckResult "cloudflared tunnel route dns list" $true "WARN: exitCode=$LASTEXITCODE (skip fail)"
  } else {
    $ok = ($routeText -match [regex]::Escape($Domain))
    Write-CheckResult "cloudflared tunnel route dns list" $ok (($routeOut | Select-Object -First 3) -join " | ")
  }
} catch {
  Write-CheckResult "cloudflared tunnel route dns list" $true "WARN: $($_.Exception.Message)"
}

# 4) tunnel info + resolve Tunnel ID
try {
  $tunnelLookup = $TunnelName
  $tunnelNameUuid = Get-FirstUuid $TunnelName
  if ($tunnelNameUuid) {
    $tunnelId = $tunnelNameUuid
    $tunnelLookup = $tunnelNameUuid
  }

  Write-Host "Checking tunnel using input='$TunnelName' (lookup='$tunnelLookup')" -ForegroundColor DarkCyan

  $infoOut = & cloudflared tunnel info $tunnelLookup 2>&1
  $text = $infoOut | Out-String
  $resolvedTunnelId = Get-FirstUuid $text
  if ($resolvedTunnelId) { $tunnelId = $resolvedTunnelId }

  if (-not $tunnelId -and -not $tunnelNameUuid) {
    $listOut = & cloudflared tunnel list 2>&1
    $listText = $listOut | Out-String
    $line = ($listText -split "`r?`n" | Where-Object { $_ -match [regex]::Escape($TunnelName) } | Select-Object -First 1)
    $tunnelId = Get-FirstUuid $line
  }

  $ok = ($LASTEXITCODE -eq 0 -and ($text -match "connector" -or $text -match "active"))
  $detail = (($infoOut | Select-Object -First 5) -join " | ")
  if ($tunnelId) { $detail = "$detail | tunnelId=$tunnelId" }
  Write-CheckResult "cloudflared tunnel info $tunnelLookup" $ok $detail
} catch {
  Write-CheckResult "cloudflared tunnel info $TunnelName" $false $_.Exception.Message
}

# 4.1) DNS UUID vs Tunnel ID mismatch check (root cause for 1033)
if ($dnsUuid -and $tunnelId) {
  if ($dnsUuid -eq $tunnelId) {
    Write-CheckResult "DNS route UUID matches tunnel ID" $true "uuid=$dnsUuid"
  } else {
    $msg = "DNS route points to $dnsUuid but tunnel is $tunnelId"
    Write-CheckResult "DNS route UUID matches tunnel ID" $false $msg
    $script:RouteFixCommand = "cloudflared tunnel route dns -f $tunnelId $Domain"
  }
} else {
  if (-not $dnsUuid) {
    Write-CheckResult "DNS route UUID matches tunnel ID" $true "WARN: domain is proxied; no CNAME to parse"
  } else {
    $miss = "dnsUuid=$dnsUuid tunnelId=$tunnelId"
    Write-CheckResult "DNS route UUID matches tunnel ID" $false "cannot compare ($miss)"
  }
}

# 5) domain health (Windows schannel friendly)
$domainHealthUrl = "https://$Domain/api/health"
try {
  $domainOut = & curl.exe -sS -o NUL -w "%{http_code}" --max-time 10 --ssl-no-revoke "$domainHealthUrl" 2>&1
  $script:DomainHealthStatus = "$domainOut"
  $ok = ($LASTEXITCODE -eq 0 -and "$domainOut" -eq "200")
  Write-CheckResult "Domain health $domainHealthUrl" $ok "status=$domainOut"
} catch {
  Write-CheckResult "Domain health $domainHealthUrl" $false $_.Exception.Message
}

if ($script:RouteFixCommand) {
  Write-Host ""
  Write-Host "Route fix command (copy/paste):" -ForegroundColor Yellow
  Write-Host $script:RouteFixCommand -ForegroundColor Yellow
}

if ($script:DomainHealthStatus -eq "530") {
  $hintTunnelId = if ($tunnelId) { $tunnelId } else { "<tunnelId>" }
  Write-Host ""
  Write-Host "Hint: domain health returned 530. Verify tunnel is running with correct flag order:" -ForegroundColor Yellow
  Write-Host "cloudflared --config <cfg> --loglevel debug tunnel run $hintTunnelId" -ForegroundColor Yellow
}

Write-Host ""
if ($script:FailCount -eq 0) {
  Write-Host "SMOKE RESULT: PASS ✅" -ForegroundColor Green
  exit 0
}

Write-Host "SMOKE RESULT: FAIL ❌ ($script:FailCount checks failed)" -ForegroundColor Red
exit 1
