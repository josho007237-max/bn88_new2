param(
  [int]$Port = 3000
)

$ErrorActionPreference = "Stop"
$passCount = 0
$warnCount = 0
$failCount = 0

function Pass([string]$Message) {
  Write-Host "[PASS] $Message" -ForegroundColor Green
  $script:passCount++
}

function Fail([string]$Message) {
  Write-Host "[FAIL] $Message" -ForegroundColor Red
  $script:failCount++
}

function Warn([string]$Message) {
  Write-Host "[WARN] $Message" -ForegroundColor Yellow
  $script:warnCount++
}

function Info([string]$Message) {
  Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Get-EnvValueFromFile([string]$Path, [string]$Key) {
  $line = Get-Content -Path $Path | Where-Object {
    $_ -match "^\s*$([regex]::Escape($Key))\s*="
  } | Select-Object -First 1

  if (-not $line) { return $null }
  $raw = ($line -split "=", 2)[1].Trim()

  if ($raw.StartsWith('"') -and $raw.EndsWith('"') -and $raw.Length -ge 2) {
    return $raw.Substring(1, $raw.Length - 2)
  }
  if ($raw.StartsWith("'") -and $raw.EndsWith("'") -and $raw.Length -ge 2) {
    return $raw.Substring(1, $raw.Length - 2)
  }
  return $raw
}

$cwd = (Get-Location).Path
$cwdLeaf = Split-Path -Leaf $cwd
$packageJsonPath = Join-Path $cwd "package.json"
$envPath = Join-Path $cwd ".env"

Info "Running dev check in: $cwd"

# 1) verify current folder is bn88-backend-v12 and package.json exists
if ($cwdLeaf -eq "bn88-backend-v12" -and (Test-Path $packageJsonPath)) {
  Pass "Current directory is bn88-backend-v12 and package.json exists"
} else {
  Fail "Please run from bn88-backend-v12 (package.json missing or wrong folder)"
  Write-Host "      Suggested: cd ...\\bn88-backend-v12" -ForegroundColor DarkYellow
  Write-Host ""
  Write-Host "Summary: PASS=$passCount WARN=$warnCount FAIL=$failCount" -ForegroundColor Cyan
  exit 1
}

# 2) parse .env blockers
if (Test-Path $envPath) {
  Pass "Found .env"

  $envLines = Get-Content -Path $envPath
  $secretLines = @($envLines | Where-Object { $_ -match "^\s*SECRET_ENC_KEY_BN9=" })
  if ($secretLines.Count -gt 1) {
    Fail "Duplicate SECRET_ENC_KEY_BN9 found ($($secretLines.Count) lines)"
  } elseif ($secretLines.Count -eq 1) {
    Pass "SECRET_ENC_KEY_BN9 appears exactly once"
  } else {
    Fail "SECRET_ENC_KEY_BN9 line not found"
  }

  $lineApiLines = @($envLines | Where-Object { $_ -match "^\s*LINE_BOT_API_URL=" })
  if ($lineApiLines.Count -gt 0) {
    $lineApiRaw = $lineApiLines[0]
    $lineApiValue = ($lineApiRaw -split "=", 2)[1].Trim()
    if ($lineApiValue.StartsWith('"') -and $lineApiValue.EndsWith('"') -and $lineApiValue.Length -ge 2) {
      $lineApiValue = $lineApiValue.Substring(1, $lineApiValue.Length - 2)
    }
    if ($lineApiValue.StartsWith("'") -and $lineApiValue.EndsWith("'") -and $lineApiValue.Length -ge 2) {
      $lineApiValue = $lineApiValue.Substring(1, $lineApiValue.Length - 2)
    }

    if ($lineApiValue -eq "https://api.line.me") {
      Pass "LINE_BOT_API_URL looks valid"
    } elseif ($lineApiValue -match "^https://api\.line\.me.+$") {
      Fail "LINE_BOT_API_URL has extra concatenated text after https://api.line.me"
    } else {
      Pass "LINE_BOT_API_URL does not contain concatenation symptom"
    }
  } else {
    Warn "LINE_BOT_API_URL line not found in .env"
  }
} else {
  Fail ".env not found"
}

# 3) check port 3000 listener (netstat + Test-NetConnection)
$listenPid3000 = (Get-NetTCPConnection -LocalPort 3000 -State Listen).OwningProcess
if ($listenPid3000 -is [array]) {
  $listenPid3000 = ($listenPid3000 | Where-Object { $_ -gt 0 } | Select-Object -First 1)
}
if ($listenPid3000) {
  $listenProc3000 = Get-CimInstance Win32_Process -Filter "ProcessId=$listenPid3000" -ErrorAction SilentlyContinue
  $listenCommand3000 = if ($listenProc3000) { $listenProc3000.CommandLine } else { $null }
  Info "Port 3000 owning PID: $listenPid3000"
  Info "Port 3000 command line: $listenCommand3000"
} else {
  Warn "No LISTEN process found on port 3000 via Get-NetTCPConnection"
}

# 3) check port listener (netstat + Test-NetConnection)
$netstatListening = $false
$tncListening = $false
try {
  $pattern = "LISTENING.*[:\.]$Port\s"
  $netstatListening = [bool](netstat -ano | Select-String -Pattern $pattern)
  if ($netstatListening) {
    Pass "Port $Port is LISTENING (netstat)"
  } else {
    Fail "Port $Port is not LISTENING (netstat). Suggested: npm run dev"
  }
} catch {
  Fail "netstat check failed: $($_.Exception.Message)"
}

try {
  $tnc = Test-NetConnection -ComputerName "127.0.0.1" -Port $Port -WarningAction SilentlyContinue
  $tncListening = [bool]$tnc.TcpTestSucceeded
  if ($tncListening) {
    Pass "Port $Port reachable on 127.0.0.1 (Test-NetConnection)"
  } else {
    Fail "Port $Port not reachable on 127.0.0.1 (Test-NetConnection). Suggested: npm run dev"
  }
} catch {
  Fail "Test-NetConnection failed: $($_.Exception.Message)"
}

# 4) check redis 127.0.0.1:6380 (warn only)
try {
  $redis = Test-NetConnection -ComputerName "127.0.0.1" -Port 6380 -WarningAction SilentlyContinue
  if ([bool]$redis.TcpTestSucceeded) {
    Pass "Redis reachable at 127.0.0.1:6380"
  } else {
    Warn "Redis not reachable at 127.0.0.1:6380"
    Write-Host "      Start redis: docker run -d --name bn88-redis -p 6380:6379 redis:7-alpine" -ForegroundColor DarkYellow
  }
} else {
  Warn "Redis check failed: $($_.Exception.Message)"
  Write-Host "      Start redis: docker run -d --name bn88-redis -p 6380:6379 redis:7-alpine" -ForegroundColor DarkYellow
}

# 5) summary
Write-Host ""
Write-Host "Summary: PASS=$passCount WARN=$warnCount FAIL=$failCount" -ForegroundColor Cyan

if ($failCount -gt 0) {
  Fail "DEV CHECK FAILED"
  exit 1
}
Pass "DEV CHECK PASSED"
exit 0
