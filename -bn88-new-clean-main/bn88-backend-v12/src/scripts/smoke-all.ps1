param(
  [string]$BaseUrl = 'http://127.0.0.1:3000',
  [string]$Email = '',
  [string]$Password = '',
  [string]$Tenant = 'bn9',
  [switch]$ExpectSse
)

$ErrorActionPreference = 'Stop'
$steps = @()
$allPassed = $true
$corePassed = $true

function Write-Step([string]$Name, [bool]$Passed, [string]$Message, [bool]$Required = $false) {
  $status = if ($Passed) { 'PASS' } else { 'FAIL' }
  Write-Host "$Name : $status - $Message"
  if (-not $Passed) {
    $global:allPassed = $false
    if ($Required) { $global:corePassed = $false }
  }
  $script:steps += [pscustomobject]@{ Name = $Name; Passed = $Passed; Message = $Message }
}

function Write-WarnStep([string]$Name, [string]$Message) {
  Write-Host "$Name : WARN - $Message" -ForegroundColor Yellow
  $script:steps += [pscustomobject]@{ Name = $Name; Passed = $null; Message = "WARN: $Message" }
}

function Get-StatusCodeFromError($Err) {
  $resp = $Err.Exception.Response
  if ($resp -and $resp.StatusCode) { return [int]$resp.StatusCode }
  return $null
}

Write-Host '=== smoke-all checks ==='

try {
  $health = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/health" -UseBasicParsing
  if ($null -eq $health) {
    Write-Step '/api/health' $false 'response is null' $true
  } elseif ($health.ok -ne $true -or $health.adminApi -ne $true) {
    Write-Step '/api/health' $false "ok=$($health.ok), adminApi=$($health.adminApi)" $true
  } else {
    Write-Step '/api/health' $true 'ok=true adminApi=true' $true
  }
} catch {
  Write-Step '/api/health' $false "$_" $true
}

if ([string]::IsNullOrWhiteSpace($Email)) { $Email = $Env:ADMIN_EMAIL }
if ([string]::IsNullOrWhiteSpace($Password)) { $Password = $Env:ADMIN_PASSWORD }

$token = $null
if ([string]::IsNullOrWhiteSpace($Email) -or [string]::IsNullOrWhiteSpace($Password)) {
  Write-Step 'admin login' $false 'ADMIN_EMAIL/ADMIN_PASSWORD missing' $true
} else {
  try {
    $body = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress
    $login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/admin/auth/login" -ContentType 'application/json' -Body $body -UseBasicParsing
    $token = $login.token
    if (-not $token) { $token = $login.accessToken }
    $tokenLen = if ($token) { $token.Length } else { 0 }
    if ([string]::IsNullOrWhiteSpace($token) -or $tokenLen -le 50) {
      Write-Step 'admin login' $false "tokenLen=$tokenLen" $true
      $token = $null
    } else {
      Write-Step 'admin login' $true "tokenLen=$tokenLen" $true
    }
  } catch {
    Write-Step 'admin login' $false "$_" $true
    $token = $null
  }
}

if ($token) {
  try {
    $headers = @{ Authorization = "Bearer $token"; 'x-tenant' = $Tenant }
    $bots = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/admin/bots" -Headers $headers -UseBasicParsing
    $itemCount = if ($bots -and $bots.items) { $bots.items.Count } else { 0 }
    if ($bots.ok -eq $true -and $itemCount -gt 0) {
      Write-Step '/api/admin/bots' $true "ok=true items=$itemCount" $true
    } else {
      Write-Step '/api/admin/bots' $false "ok=$($bots.ok) items=$itemCount" $true
    }
  } catch {
    Write-Step '/api/admin/bots' $false "$_" $true
  }

  try {
    $curlCmd = if (Get-Command curl.exe -ErrorAction SilentlyContinue) { 'curl.exe' } elseif (Get-Command curl -ErrorAction SilentlyContinue) { 'curl' } else { $null }
    if (-not $curlCmd) {
      if ($ExpectSse) {
        Write-Step 'SSE /api/live' $false 'curl not found'
      } else {
        Write-WarnStep 'SSE /api/live' 'curl not found'
      }
    } else {
      $sseOutput = & $curlCmd -i -N --max-time 5 "$BaseUrl/api/live/$Tenant?token=$token" 2>&1
      $sseText = ($sseOutput | Out-String)
      if ($sseText -match 'HTTP/\S+\s+200') {
        Write-Step 'SSE /api/live' $true 'HTTP 200'
      } elseif ($sseText -match 'HTTP/\S+\s+401' -or $sseText -match 'HTTP/\S+\s+403') {
        if ($ExpectSse) {
          Write-Step 'SSE /api/live' $false 'SSE auth pending'
        } else {
          Write-WarnStep 'SSE /api/live' 'SSE auth pending'
        }
      } else {
        if ($ExpectSse) {
          Write-Step 'SSE /api/live' $false 'unexpected SSE response'
        } else {
          Write-WarnStep 'SSE /api/live' 'unexpected SSE response'
        }
      }
    }
  } catch {
    if ($ExpectSse) {
      Write-Step 'SSE /api/live' $false "$_"
    } else {
      Write-WarnStep 'SSE /api/live' "$_"
    }
  }
} else {
  Write-Step '/api/admin/bots' $false 'skipped (no token)' $true
  if ($ExpectSse) {
    Write-Step 'SSE /api/live' $false 'skipped (no token)'
  } else {
    Write-WarnStep 'SSE /api/live' 'skipped (no token)'
  }
}

try {
  $dummyBody = '{}' 
  $null = Invoke-WebRequest -Method Post -Uri "$BaseUrl/api/webhooks/line" -Body $dummyBody -ContentType 'application/json' -UseBasicParsing
  Write-Step '/api/webhooks/line' $true 'route exists (non-404)'
} catch {
  $statusCode = Get-StatusCodeFromError $_
  if ($statusCode -eq 404) {
    Write-Step '/api/webhooks/line' $false '404 route missing'
  } elseif ($statusCode) {
    Write-Step '/api/webhooks/line' $true "route exists (HTTP $statusCode)"
  } else {
    Write-WarnStep '/api/webhooks/line' "unable to determine status: $_"
  }
}

Write-Host "`n=== Summary ==="
foreach ($s in $steps) {
  if ($null -eq $s.Passed) {
    Write-Host "$($s.Name): $($s.Message)"
  } else {
    $stat = if ($s.Passed) { 'PASS' } else { 'FAIL' }
    Write-Host "$($s.Name): $stat - $($s.Message)"
  }
}

if ($corePassed) {
  Write-Host 'All required checks passed'
  exit 0
}
Write-Host 'Required checks failed (health/login/bots)'
exit 1
