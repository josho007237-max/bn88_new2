# ===============================================
# BN88 Smoke Test Script
# ===============================================
# Performs quick health checks for local development.
# Exit code:
# - 0 = all required checks passed
# - 1 = one or more required checks failed
# ===============================================

param(
    [switch]$Verbose,
    [switch]$SkipAPI
)

$script:testsPassed = 0
$script:testsFailed = 0
$script:testsSkipped = 0

function Add-Pass {
    param([string]$Message)
    $script:testsPassed++
    Write-Host "  PASS  $Message" -ForegroundColor Green
}

function Add-Fail {
    param([string]$Message)
    $script:testsFailed++
    Write-Host "  FAIL  $Message" -ForegroundColor Red
}

function Add-Skip {
    param([string]$Message)
    $script:testsSkipped++
    Write-Host "  SKIP  $Message" -ForegroundColor Yellow
}

function Test-PortListening {
    param(
        [string]$Name,
        [int]$Port,
        [switch]$Optional
    )

    Write-Host "Testing port $Port ($Name)" -ForegroundColor Cyan
    $listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($listeners) {
        Add-Pass "Port $Port is listening"
        return $true
    }

    if ($Optional) {
        Add-Skip "Port $Port is not listening (optional)"
        return $false
    }

    Add-Fail "Port $Port is not listening"
    return $false
}

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Method = "GET",
        [hashtable]$Headers = @{},
        [object]$Body = $null,
        [int[]]$SuccessStatusCodes = @(200)
    )

    Write-Host "Testing endpoint ($Name): $Url" -ForegroundColor Cyan
    try {
        $request = @{
            Uri = $Url
            Method = $Method
            TimeoutSec = 10
            ErrorAction = "Stop"
        }

        if ($Headers.Count -gt 0) {
            $request.Headers = $Headers
        }

        if ($null -ne $Body) {
            if ($Body -is [string]) {
                $request.Body = $Body
            } else {
                $request.Body = $Body | ConvertTo-Json -Depth 10
            }
            $request.ContentType = "application/json"
        }

        $response = Invoke-WebRequest @request
        $statusCode = [int]$response.StatusCode
        if ($SuccessStatusCodes -contains $statusCode) {
            Add-Pass "$Name returned HTTP $statusCode"
            if ($Verbose -and $response.Content) {
                $preview = $response.Content.Substring(0, [Math]::Min(200, $response.Content.Length))
                Write-Host "    Response preview: $preview" -ForegroundColor Gray
            }
            return $true
        }

        Add-Fail "$Name returned HTTP $statusCode (expected: $($SuccessStatusCodes -join ', '))"
        return $false
    } catch {
        $statusCode = $null
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }

        if ($null -ne $statusCode -and ($SuccessStatusCodes -contains $statusCode)) {
            Add-Pass "$Name returned HTTP $statusCode"
            return $true
        }

        if ($null -ne $statusCode) {
            Add-Fail "$Name returned HTTP $statusCode (expected: $($SuccessStatusCodes -join ', '))"
        } else {
            Add-Fail "$Name error: $($_.Exception.Message)"
        }
        return $false
    }
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  BN88 Smoke Test Suite" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Phase 1: Port Checks" -ForegroundColor Magenta
$backendPortOk = Test-PortListening -Name "Backend API" -Port 3000
$frontendPortOk = Test-PortListening -Name "Frontend Dashboard" -Port 5555
$redisPortOk = Test-PortListening -Name "Redis" -Port 6380 -Optional
Write-Host ""

Write-Host "Phase 2: Endpoint Checks" -ForegroundColor Magenta
Test-Endpoint -Name "Backend Health" -Url "http://localhost:3000/api/health" -SuccessStatusCodes @(200) | Out-Null
Test-Endpoint -Name "Frontend Home" -Url "http://localhost:5555/" -SuccessStatusCodes @(200) | Out-Null
if ($redisPortOk) {
    Test-Endpoint -Name "Backend Redis Health" -Url "http://localhost:3000/api/health/redis" -SuccessStatusCodes @(200) | Out-Null
} else {
    Add-Skip "Skipping /api/health/redis because Redis port 6380 is not listening"
}
Write-Host ""

if (-not $SkipAPI) {
    Write-Host "Phase 3: API Reachability" -ForegroundColor Magenta
    $loginHeaders = @{ "x-tenant" = "bn9" }
    $loginBody = @{
        email = "invalid-user@local.test"
        password = "invalid-password"
    }
    Test-Endpoint `
        -Name "Admin Login Endpoint" `
        -Url "http://localhost:3000/api/admin/auth/login" `
        -Method "POST" `
        -Headers $loginHeaders `
        -Body $loginBody `
        -SuccessStatusCodes @(200, 400, 401, 403, 422) | Out-Null
    Write-Host ""
} else {
    Add-Skip "Skipping API reachability phase (-SkipAPI)"
    Write-Host ""
}

if (-not $backendPortOk) {
    Write-Host "Hint: run backend with 'npm run dev' in bn88-backend-v12" -ForegroundColor Yellow
}
if (-not $frontendPortOk) {
    Write-Host "Hint: run frontend with 'npm run dev' in bn88-frontend-dashboard-v12" -ForegroundColor Yellow
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Passed : $script:testsPassed" -ForegroundColor Green
Write-Host "Failed : $script:testsFailed" -ForegroundColor $(if ($script:testsFailed -gt 0) { "Red" } else { "Gray" })
Write-Host "Skipped: $script:testsSkipped" -ForegroundColor Yellow
Write-Host ""

if ($script:testsFailed -eq 0) {
    Write-Host "Smoke test passed." -ForegroundColor Green
    exit 0
}

Write-Host "Smoke test failed." -ForegroundColor Red
exit 1
