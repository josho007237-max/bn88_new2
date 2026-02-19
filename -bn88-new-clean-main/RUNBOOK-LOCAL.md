# RUNBOOK-LOCAL - BN88 New Clean

Quick reference guide for local development. For detailed instructions, see [SETUP.md](SETUP.md).

## 🚀 Quick Start

### Start Everything

```powershell
# From repository root
.\start-dev.ps1

# หรือรันทั้งหมด (backend + tunnel + dashboard + smoke-domain)
pwsh -File .\run-all.ps1
```

Opens two PowerShell windows:
- Backend on http://localhost:3000
- Frontend on http://localhost:5555

### Stop Everything

```powershell
.\stop-dev.ps1
```

### Run Tests

```powershell
.\smoke.ps1
```

## 🔧 Backend (bn88-backend-v12)

### First-Time Setup

```powershell
cd .\bn88-backend-v12

# Install dependencies
npm install

# Setup environment
copy .env.example .env
# Edit .env as needed

# Initialize database
npx prisma generate
npx prisma db push

# Seed data
npm run seed:dev
```

### Daily Development

```powershell
cd .\bn88-backend-v12

# Start development server
npm run dev

# In another terminal, run Prisma Studio
npm run studio
# Access at http://localhost:5556
```

### Health Check

```powershell
# Test backend is running
curl http://localhost:3000/api/health

# Expected: {"ok":true,"time":"...","adminApi":true}
```

### Database Commands

```powershell
cd .\bn88-backend-v12

# Push schema changes (dev only)
npx prisma db push

# Create migration
npx prisma migrate dev --name your_migration_name

# Open database GUI
npm run studio

# Reset database (⚠️ deletes data!)
npx prisma migrate reset --force

# Reseed database
npm run seed:dev
```

## 🎨 Frontend (bn88-frontend-dashboard-v12)

### First-Time Setup

```powershell
cd .\bn88-frontend-dashboard-v12

# Install dependencies
npm install

# Setup environment
copy .env.example .env
# Defaults are usually fine
```

### Daily Development

```powershell
cd .\bn88-frontend-dashboard-v12

# Start development server
npm run dev

# Access at http://localhost:5555
```

### Build & Test

```powershell
cd .\bn88-frontend-dashboard-v12

# Type check
npm run typecheck

# Lint
npm run lint

# Build for production
npm run build

# Preview build
npm run preview
```

## 💾 Database Options

### Option A: SQLite (Quickest)

```powershell
# In bn88-backend-v12/.env
DATABASE_URL=file:./prisma/dev.db

# Initialize
npx prisma db push
```

✅ No Docker needed
✅ Fast setup
⚠️ Single-file database
⚠️ No concurrent writes

### Option B: PostgreSQL with Docker (Recommended)

```powershell
# Start PostgreSQL
docker-compose up -d db

# In bn88-backend-v12/.env
DATABASE_URL=postgresql://admin:password@localhost:5432/bn88?schema=public

# Initialize
npx prisma db push
```

✅ Production-like environment
✅ Better performance
✅ Concurrent access
⚠️ Requires Docker

### Option C: Your Own PostgreSQL

```powershell
# In bn88-backend-v12/.env
DATABASE_URL=postgresql://YOUR_USER:YOUR_PASSWORD@YOUR_HOST:5432/bn88?schema=public

# Initialize
npx prisma db push
```

## 📦 Redis (Optional)

### Start Redis

```powershell
# With docker-compose (port 6380)
docker-compose up -d redis

# Or standalone (standard port 6379)
docker run --rm -p 6380:6379 redis:7-alpine
```

### Configure Backend

```powershell
# In bn88-backend-v12/.env
REDIS_URL=redis://127.0.0.1:6380
REDIS_PORT=6380
ENABLE_REDIS=1
```

### Disable Redis

```powershell
# In bn88-backend-v12/.env
DISABLE_REDIS=1
```

### Test Redis

```powershell
# Using redis-cli
redis-cli -p 6380 ping
# Expected: PONG

# Or check health endpoint
curl http://localhost:3000/api/health/redis
```

## 🔑 Default Login

```
Email:    root@bn9.local
Password: bn9@12345
Tenant:   bn9
```

## 🌐 Ports

| Service | Port | URL |
|---------|------|-----|
| Backend | 3000 | http://localhost:3000 |
| Frontend | 5555 | http://localhost:5555 |
| Prisma Studio | 5556 | http://localhost:5556 |
| Redis | 6380 | redis://localhost:6380 |
| PostgreSQL | 5432 | postgresql://localhost:5432 |
| LINE Platform | 8080 | http://localhost:8080 |

## 🔍 Port Checks

```powershell
# Check what's using ports
netstat -ano | findstr ":3000"
netstat -ano | findstr ":5555"
netstat -ano | findstr ":6380"

# Or with PowerShell
Get-NetTCPConnection -LocalPort 3000 -State Listen
Get-NetTCPConnection -LocalPort 5555 -State Listen
Get-NetTCPConnection -LocalPort 6380 -State Listen
```

## 🐛 Common Issues

### Port Already in Use

```powershell
# Stop all dev services
.\stop-dev.ps1

# Or kill specific port
Get-NetTCPConnection -LocalPort 3000 -State Listen | 
  ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
```

### "Cannot find module"

```powershell
# Clean reinstall
cd bn88-backend-v12
rm -r node_modules
npm install

# Or
npm ci
```

### "Prisma Client not initialized"

```powershell
cd bn88-backend-v12
npx prisma generate
```

### Database connection failed

```powershell
# Check DATABASE_URL in .env
# If using Docker:
docker-compose up -d db

# Test connection:
npx prisma db push
```

### Frontend can't reach backend

1. Check backend is running: http://localhost:3000/api/health
2. Check proxy config: `vite.config.ts`
3. Check CORS: `ALLOWED_ORIGINS` in backend `.env`
4. Clear browser cache/cookies

## 🌍 LINE Webhook (HTTPS Required)

LINE webhooks require HTTPS. Use Cloudflare Tunnel for local development:

```powershell
# Install cloudflared first (one-time)
# Download from: https://github.com/cloudflare/cloudflared/releases

# Basic tunnel
cloudflared tunnel --url http://localhost:3000

# With HTTP/2 (recommended)
cloudflared tunnel --protocol http2 --url http://localhost:3000

# With debug logs
cloudflared tunnel --protocol http2 --url http://localhost:3000 --loglevel debug
```

**Webhook URL format:**
```
https://<tunnel-url>/api/webhooks/line/bn9/dev-bot
```

**Test tunnel:**
```powershell
# Local endpoint
curl http://localhost:3000/api/health

# Tunnel endpoint  
curl https://<tunnel-url>/api/health
```

### Troubleshoot Tunnel 404

```powershell
# 1. Kill old tunnels
Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force

# 2. Start fresh
cloudflared tunnel --protocol http2 --url http://127.0.0.1:3000 --loglevel debug

# 3. Test with details
$r = Invoke-WebRequest "https://<tunnel-url>/api/health" -SkipHttpErrorCheck
$r.StatusCode
$r.Headers
```

## 📝 Useful Commands

### Git

```powershell
# Check status
git status -sb

# View changes
git diff

# Discard changes
git checkout -- .
```

### Prisma

```powershell
cd bn88-backend-v12

# Validate schema
npx prisma validate

# Format schema
npx prisma format

# View schema in GUI
npm run studio
```

### Process Management

```powershell
# List all node processes
Get-Process node

# Kill all node processes (⚠️ careful!)
Get-Process node | Stop-Process -Force

# Find process by port
Get-NetTCPConnection -LocalPort 3000 | 
  Select-Object -ExpandProperty OwningProcess
```

## 🔒 PowerShell Best Practice

⚠️ **Important:** Always use `$procId` instead of `$pid`

```powershell
# ✅ CORRECT
$procId = $connection.OwningProcess
Stop-Process -Id $procId -Force

# ❌ WRONG - $PID is reserved in PowerShell
$pid = $connection.OwningProcess
Stop-Process -Id $pid -Force
```

`$PID` is a PowerShell automatic variable (current PowerShell process ID).

## 📚 More Information

- [SETUP.md](SETUP.md) - Detailed setup guide
- [README.md](README.md) - Project overview  
- [RUNBOOK.md](RUNBOOK.md) - Full operational guide
- [CONTRIBUTING.md](CONTRIBUTING.md) - How to contribute

## 🆘 Need Help?

1. Run smoke tests: `.\smoke.ps1`
2. Check [SETUP.md](SETUP.md) troubleshooting section
3. Review application logs
4. Check [GitHub Issues](https://github.com/josho007237-max/-bn88-new-clean/issues)
