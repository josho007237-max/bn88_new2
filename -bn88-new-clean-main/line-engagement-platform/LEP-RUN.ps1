$ErrorActionPreference = "Stop"

cd C:\BN88\BN88-new-clean\line-engagement-platform

Write-Host "== Validate compose =="
docker compose config | Out-Null

Write-Host "== Up (build) =="
docker compose up -d --build

Write-Host "== Wait health (max 60s) =="
$urls = @(
  "http://localhost:8080/api/health",
  "http://localhost:8080/health"
)

$ok = $false
for ($i=1; $i -le 30; $i++) {
  foreach ($u in $urls) {
    try {
      $r = Invoke-WebRequest -UseBasicParsing $u -TimeoutSec 2
      if ($r.StatusCode -eq 200) { $ok = $true; break }
    } catch {}
  }
  if ($ok) { break }
  Start-Sleep -Seconds 2
}

docker compose ps

if (-not $ok) {
  Write-Host "`n[FAIL] health not reachable"
  Write-Host "== lep logs =="
  docker compose logs --tail 200 lep
  exit 1
}

Write-Host "`n[OK] LEP healthy"

# (ถ้าจะ migrate จริง ค่อยปลดคอมเมนต์)
# docker compose exec lep npm run prisma:generate
# docker compose exec lep npm run prisma:migrate
# docker compose exec lep npm run prisma:seed
