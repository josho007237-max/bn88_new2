param(
  [Parameter(Mandatory = $true)]
  [string]$UserName,

  [Parameter(Mandatory = $true)]
  [string]$NoReplyEmail,

  [int]$RewriteLast = 1,

  [switch]$AbortRebase,

  [switch]$Push
)

$ErrorActionPreference = 'Stop'

function Run-Git {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  & git @Args
  if ($LASTEXITCODE -ne 0) {
    throw "git command failed: git $($Args -join ' ')"
  }
}

function Show-State {
  Write-Host "`n=== BEFORE/AFTER CHECK ===" -ForegroundColor Cyan
  Run-Git config --get user.email
  Run-Git log "--format=%h %an <%ae>" -n 5
}

# 1) Ensure current directory is inside a git repo
& git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) {
  throw 'Current folder is not inside a git repository.'
}

$gitDir = (git rev-parse --git-dir).Trim()
if ([string]::IsNullOrWhiteSpace($gitDir)) {
  throw 'Unable to resolve .git directory.'
}

$rebaseMerge = Join-Path $gitDir 'rebase-merge'
$rebaseApply = Join-Path $gitDir 'rebase-apply'
$rebaseInProgress = (Test-Path $rebaseMerge) -or (Test-Path $rebaseApply)

# 2) Handle paused rebase
if ($rebaseInProgress) {
  Write-Host '[WARN] Rebase is currently in progress.' -ForegroundColor Yellow
  if ($AbortRebase) {
    Write-Host '[INFO] Aborting rebase...' -ForegroundColor Yellow
    Run-Git rebase --abort
    Write-Host '[OK] Rebase aborted.' -ForegroundColor Green
  }
  else {
    throw 'Rebase is in progress. Resolve/continue it first, or re-run this script with -AbortRebase.'
  }
}

if ($NoReplyEmail -notmatch '@users\.noreply\.github\.com$') {
  throw 'NoReplyEmail must end with @users.noreply.github.com'
}

if ($RewriteLast -lt 1) {
  throw 'RewriteLast must be >= 1'
}

Write-Host '[INFO] BEFORE' -ForegroundColor Cyan
Show-State

# 3) Set repo-local git identity
Run-Git config user.name $UserName
Run-Git config user.email $NoReplyEmail

# 4) Rewrite last N commits author non-interactively
Write-Host "`n[INFO] Rewriting author for last $RewriteLast commit(s)..." -ForegroundColor Yellow
$env:GIT_SEQUENCE_EDITOR = ':'
Run-Git rebase -i "HEAD~$RewriteLast" --exec "git commit --amend --no-edit --reset-author"
Remove-Item Env:GIT_SEQUENCE_EDITOR -ErrorAction SilentlyContinue

Write-Host '[INFO] AFTER' -ForegroundColor Cyan
Show-State

# 5) Optional push
if ($Push) {
  $branch = (git rev-parse --abbrev-ref HEAD).Trim()
  if ([string]::IsNullOrWhiteSpace($branch)) {
    throw 'Cannot detect current branch.'
  }

  Write-Host "`n[INFO] Pushing branch: $branch" -ForegroundColor Yellow
  & git ls-remote --exit-code --heads origin $branch *> $null
  if ($LASTEXITCODE -eq 0) {
    Run-Git push --force-with-lease origin $branch
  }
  else {
    Run-Git push -u origin $branch
  }

  Write-Host '[OK] Push completed.' -ForegroundColor Green
}

Write-Host "`n[DONE] Completed successfully." -ForegroundColor Green
