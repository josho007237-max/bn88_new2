# RUNBOOK - BN88 New Clean

This runbook provides operational procedures for running and managing the BN88 platform in development and production environments.

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Backend Operations](#backend-operations)
- [Frontend Operations](#frontend-operations)
- [Database Operations](#database-operations)
- [Redis Operations](#redis-operations)
- [Health Checks](#health-checks)
- [Troubleshooting](#troubleshooting)
- [Production Deployment](#production-deployment)

## 🚀 Quick Start

### Start Entire Stack (Development)

```powershell
# From repository root
.\start-dev.ps1
```

This starts:
- Backend on port 3000
- Frontend on port 5555

### Stop Entire Stack

```powershell
.\stop-dev.ps1
```

### Run Smoke Tests

```powershell
.\smoke.ps1
```

## 🔧 Backend Operations

### Install Dependencies

```powershell
cd .\bn88-backend-v12
npm install
```

### Setup Environment

```powershell
# Copy environment template
copy .env.example .env

# Edit .env and configure:
# - DATABASE_URL
# - JWT_SECRET
# - REDIS_URL (if using Redis)
```

### Initialize Database

```powershell
# Generate Prisma client
npx prisma generate

# Push schema to database (development)
npx prisma db push

# Or apply migrations (production)
npx prisma migrate deploy

# Seed database with admin user
npm run seed:dev
```

### Start Backend

```powershell
# Development mode (with auto-reload)
npm run dev

# Production mode
npm start
```

### Backend Health Check

```powershell
# Test health endpoint
curl http://localhost:3000/api/health

# Expected response:
# {"ok":true,"time":"2024-XX-XXTXX:XX:XX.XXXZ","adminApi":true}

# Test Redis health (if enabled)
curl http://localhost:3000/api/health/redis
```

### Database Management

```powershell
# Open Prisma Studio (database GUI)
npm run studio
# Access at http://localhost:5556

# Create new migration
npx prisma migrate dev --name your_migration_name

# Apply migrations
npx prisma migrate deploy

# Reset database (⚠️ deletes all data!)
npx prisma migrate reset --force

# Validate schema
npx prisma validate

# Format schema
npx prisma format
```

### Backup & Restore (Development with SQLite)

**Backup SQLite + media:**

```powershell
pwsh -File .\bn88-backend-v12\scripts\backup-dev.ps1
```

**Restore from backup:**

```powershell
pwsh -File .\bn88-backend-v12\scripts\restore-dev.ps1 -BackupFile .\bn88-backend-v12\backups\db-<timestamp>.sqlite
```

### TypeScript Compilation

```powershell
# Type check only (no output)
npm run typecheck

# Build for production
npm run build

# Output: dist/
```

## 🎨 Frontend Operations

### Install Dependencies

```powershell
cd .\bn88-frontend-dashboard-v12
npm install
```

### Setup Environment

```powershell
# Copy environment template
copy .env.example .env

# The defaults should work for local development
```

### Start Frontend

```powershell
# Development mode
npm run dev
# Access at http://localhost:5555

# Build for production
npm run build

# Preview production build
npm run preview
```

### Type Checking & Linting

```powershell
# Type check
npm run typecheck

# Lint code
npm run lint

# Fix linting errors
npm run lint:fix

# Format code
npm run format
```

## 💾 Database Operations

### Using PostgreSQL (Recommended)

#### With Docker Compose

```powershell
# Start PostgreSQL
docker-compose up -d db

# View logs
docker-compose logs -f db

# Stop PostgreSQL
docker-compose down db
```

**Connection String:**
```
postgresql://admin:password@localhost:5432/bn88?schema=public
```

#### Standalone PostgreSQL

```powershell
# If you have PostgreSQL installed separately
# Update DATABASE_URL in .env to point to your server

# Example:
# DATABASE_URL=postgresql://YOUR_USER:YOUR_PASSWORD@localhost:5432/bn88
```

### Using SQLite (Quick Development)

```powershell
# In .env file:
DATABASE_URL=file:./prisma/dev.db

# Initialize
cd bn88-backend-v12
npx prisma db push
```

### Seeding Data

```powershell
cd bn88-backend-v12

# Seed everything (admin + bots + sample data)
npm run seed:dev

# Seed admin user only
npm run seed:admin

# Seed bots only
npm run seed:bot

# Custom seeding
npm run seed
```

### Database Migrations

```powershell
cd bn88-backend-v12

# Create a new migration
npx prisma migrate dev --name add_new_field

# Apply pending migrations
npx prisma migrate deploy

# Check migration status
npx prisma migrate status

# Reset and reapply all migrations (⚠️ destructive!)
npx prisma migrate reset --force
```

## 📦 Redis Operations

### Using Docker (Recommended)

```powershell
# Start Redis (port 6380 to avoid conflicts)
docker-compose up -d redis

# Or standalone:
docker run --rm -p 6380:6379 redis:7-alpine

# Test connection
redis-cli -p 6380 ping
# Expected: PONG
```

### Configure Backend for Redis

```powershell
# In bn88-backend-v12/.env:
REDIS_URL=redis://127.0.0.1:6380
REDIS_PORT=6380
ENABLE_REDIS=1
DISABLE_REDIS=0
```

### Disable Redis

```powershell
# In bn88-backend-v12/.env:
DISABLE_REDIS=1
# or
ENABLE_REDIS=0
```

## 🏥 Health Checks

### Manual Health Checks

```powershell
# Backend health
curl http://localhost:3000/api/health

# Redis health (if enabled)
curl http://localhost:3000/api/health/redis

# Frontend
curl http://localhost:5555
```

### Port Checks

```powershell
# Check if ports are listening
Get-NetTCPConnection -LocalPort 3000 -State Listen
Get-NetTCPConnection -LocalPort 5555 -State Listen
Get-NetTCPConnection -LocalPort 6380 -State Listen

# Or using netstat
netstat -ano | findstr ":3000"
netstat -ano | findstr ":5555"
netstat -ano | findstr ":6380"
```

### Automated Smoke Tests

```powershell
# Run comprehensive smoke test suite
.\smoke.ps1

# Tests:
# - Port availability
# - Health endpoints
# - API authentication
# - Service connectivity
```

## 🐛 Troubleshooting

### Port Already in Use

```powershell
# Find process using port 3000
Get-NetTCPConnection -LocalPort 3000 -State Listen | Select-Object -ExpandProperty OwningProcess

# Kill the process
Stop-Process -Id <PID> -Force

# Or use the stop script
.\stop-dev.ps1
```

### Cannot Connect to Database

**Check Connection String:**
```powershell
# In bn88-backend-v12/.env
DATABASE_URL=postgresql://admin:password@localhost:5432/bn88?schema=public

# Test connection
cd bn88-backend-v12
npx prisma db push
```

**If using Docker:**
```powershell
# Check if PostgreSQL container is running
docker ps | findstr postgres

# Start if not running
docker-compose up -d db

# Check logs
docker-compose logs db
```

### Prisma Client Not Generated

```powershell
cd bn88-backend-v12
npx prisma generate
```

### Module Not Found Errors

```powershell
# Clean install
cd bn88-backend-v12
rm -r node_modules
npm install

# Or use clean install
npm ci
```

### Frontend Can't Connect to Backend

1. **Check backend is running:** http://localhost:3000/api/health
2. **Check Vite proxy config:** `bn88-frontend-dashboard-v12/vite.config.ts`
3. **Check CORS settings:** `ALLOWED_ORIGINS` in backend `.env`
4. **Clear browser cache** and cookies

### Redis Connection Issues

```powershell
# Check if Redis is running
docker ps | findstr redis

# Or check port
Get-NetTCPConnection -LocalPort 6380 -State Listen

# Test connection
redis-cli -p 6380 ping

# If not needed, disable in .env
DISABLE_REDIS=1
```

## 🌐 LINE Webhook Operations

### Requirements

- LINE requires **HTTPS only** (no HTTP or localhost)
- Use a tunnel service like Cloudflare Tunnel

### Setup Cloudflare Tunnel

```powershell
# Basic tunnel
cloudflared tunnel --url http://localhost:3000

# With HTTP/2 protocol (if having issues)
cloudflared tunnel --protocol http2 --url http://localhost:3000

# With debug logging
cloudflared tunnel --protocol http2 --url http://localhost:3000 --loglevel debug
```

### Webhook URL Format

```
https://<tunnel-url>/api/webhooks/line/<tenant>/<botId>

Example:
https://abc-123.trycloudflare.com/api/webhooks/line/bn9/dev-bot
```

### Testing Tunnel

```powershell
# 1. Check local endpoint works
curl http://localhost:3000/api/health

# 2. Check tunnel endpoint works
curl https://<tunnel-url>/api/health

# 3. Check status code
$response = Invoke-WebRequest -Uri "https://<tunnel-url>/api/health"
$response.StatusCode  # Should be 200
```

### Troubleshooting Tunnel 404 Errors

```powershell
# 1. Kill all cloudflared processes
Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force

# 2. Start fresh tunnel with debug
cloudflared tunnel --protocol http2 --url http://127.0.0.1:3000 --loglevel debug

# 3. Test with detailed response
$r = Invoke-WebRequest "https://<tunnel-url>/" -SkipHttpErrorCheck
$r.StatusCode
$r.Headers["server"]
$r.Headers["cf-ray"]
```

## 🚀 Production Deployment

### Prerequisites

- [ ] Node.js 18+ installed
- [ ] PostgreSQL 15+ database
- [ ] Redis 7+ (recommended)
- [ ] SSL/TLS certificates
- [ ] Environment variables configured

### Environment Setup

```powershell
# Backend .env (production)
NODE_ENV=production
DATABASE_URL=postgresql://user:password@db-host:5432/bn88_prod?schema=public
JWT_SECRET=<strong-random-secret>
REDIS_URL=redis://redis-host:6379
ALLOWED_ORIGINS=https://yourdomain.com
LINE_CHANNEL_SECRET=<your-line-secret>
LINE_CHANNEL_ACCESS_TOKEN=<your-line-token>
```

### Database Migration

```powershell
cd bn88-backend-v12

# Apply migrations (production)
npx prisma migrate deploy

# Seed admin user (first time only)
npm run seed:admin
```

### Build Applications

```powershell
# Backend
cd bn88-backend-v12
npm ci --production=false
npm run build

# Frontend
cd ../bn88-frontend-dashboard-v12
npm ci --production=false
npm run build
```

### Using Docker Compose

```powershell
# Production deployment
docker-compose up -d

# View logs
docker-compose logs -f

# Restart services
docker-compose restart backend frontend

# Update and restart
git pull
docker-compose build
docker-compose up -d
```

### Process Manager (PM2)

```powershell
# Install PM2 globally
npm install -g pm2

# Start backend
cd bn88-backend-v12
pm2 start npm --name "bn88-backend" -- start

# Start frontend (with serve)
cd ../bn88-frontend-dashboard-v12
npm install -g serve
pm2 start serve --name "bn88-frontend" -- -s dist -l 5555

# Save PM2 configuration
pm2 save

# Setup PM2 to start on boot
pm2 startup
```

## 📊 Monitoring

### Check Application Logs

```powershell
# Docker logs
docker-compose logs -f backend
docker-compose logs -f frontend

# PM2 logs
pm2 logs bn88-backend
pm2 logs bn88-frontend

# Application log files
tail -f bn88-backend-v12/logs/app.log
```

### Monitor Processes

```powershell
# PM2 status
pm2 status
pm2 monit

# Docker status
docker-compose ps
docker stats
```

## 🔒 Security Notes

### PowerShell Best Practices

⚠️ **Important:** Use `$procId` instead of `$pid` in PowerShell scripts
- `$PID` is a reserved PowerShell automatic variable
- Use `$procId` for process IDs to avoid conflicts

### Production Security Checklist

- [ ] Change all default passwords
- [ ] Use strong JWT_SECRET (at least 32 characters)
- [ ] Enable HTTPS only
- [ ] Configure proper CORS origins
- [ ] Enable rate limiting
- [ ] Setup database backups
- [ ] Use environment variables (never commit secrets)
- [ ] Enable Redis authentication
- [ ] Setup monitoring and alerts
- [ ] Regular security updates

## 📚 Additional Resources

- [SETUP.md](SETUP.md) - First-time setup guide
- [README.md](README.md) - Project overview
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [Backend README](bn88-backend-v12/README.md) - Backend-specific docs
- Prisma Schema: `bn88-backend-v12/prisma/schema.prisma`

## 🆘 Getting Help

If you encounter issues:

1. Check this runbook for solutions
2. Run smoke tests: `.\smoke.ps1`
3. Check application logs
4. Review GitHub issues
5. Consult SETUP.md troubleshooting section
