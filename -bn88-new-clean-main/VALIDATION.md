# 🧪 Validation Checklist - BN88 New Clean

This document provides validation steps to ensure the project is working correctly.

## ✅ Pre-Installation Validation

### System Requirements

- [ ] Node.js 18+ installed: `node --version`
- [ ] npm 9+ installed: `npm --version`
- [ ] PowerShell 7+ installed (Windows): `pwsh --version`
- [ ] Git installed: `git --version`
- [ ] Docker Desktop installed (optional): `docker --version`

### Repository Check

```powershell
# Clone repository
git clone https://github.com/josho007237-max/-bn88-new-clean.git
cd -bn88-new-clean

# Check Node version matches .nvmrc
cat .nvmrc
node --version
```

## 📦 Backend Validation

### Installation

```powershell
cd bn88-backend-v12

# Install dependencies
npm install

# Expected: No critical errors
# Note: May see warnings, those are OK
```

### Environment Setup

```powershell
# Create .env file
copy .env.example .env

# Verify .env exists
Test-Path .env
# Expected: True

# Check key variables exist
Get-Content .env | Select-String "DATABASE_URL"
Get-Content .env | Select-String "JWT_SECRET"
Get-Content .env | Select-String "PORT"
```

### Database Initialization

#### Option A: SQLite (Quickest)

```powershell
# Edit .env to use SQLite
# DATABASE_URL=file:./prisma/dev.db

# Generate Prisma client
npx prisma generate
# Expected: ✔ Generated Prisma Client

# Push schema
npx prisma db push
# Expected: Database synchronized successfully

# Seed data
npm run seed:dev
# Expected: Seeding completed successfully
```

#### Option B: PostgreSQL (Docker)

```powershell
# Start PostgreSQL
cd ..
docker-compose up -d db

# Wait for PostgreSQL to be ready
Start-Sleep -Seconds 5

# Edit .env
# DATABASE_URL=postgresql://admin:password@localhost:5432/bn88?schema=public

cd bn88-backend-v12

# Generate and push
npx prisma generate
npx prisma db push

# Seed data
npm run seed:dev
```

### TypeScript Compilation

```powershell
# Type check
npm run typecheck
# Expected: No errors

# Build
npm run build
# Expected: Build successful, dist/ directory created
```

### Prisma Validation

```powershell
# Validate schema
npx prisma validate
# Expected: The schema is valid

# Format schema
npx prisma format
# Expected: Formatted schema.prisma

# Check migrations
npx prisma migrate status
# Expected: Shows migration status
```

## 🎨 Frontend Validation

### Installation

```powershell
cd ../bn88-frontend-dashboard-v12

# Install dependencies
npm install
# Expected: No critical errors
```

### Environment Setup

```powershell
# Create .env file
copy .env.example .env

# Verify .env exists
Test-Path .env
# Expected: True

# Check key variables
Get-Content .env | Select-String "VITE_API_BASE"
Get-Content .env | Select-String "VITE_TENANT"
```

### TypeScript Compilation

```powershell
# Type check
npm run typecheck
# Expected: No errors

# Build
npm run build
# Expected: Build successful, dist/ directory created
```

### Linting

```powershell
# Run linter
npm run lint
# Expected: No errors (warnings OK)
```

## 🚀 Runtime Validation

### Start Development Servers

```powershell
# From repository root
cd ..

# Start both backend and frontend
.\start-dev.ps1

# Expected:
# - Two PowerShell windows open
# - Backend starts on port 3000
# - Frontend starts on port 5555
# - No critical errors in logs
```

### Backend Health Check

```powershell
# Test health endpoint
curl http://localhost:3000/api/health

# Expected Response:
# {
#   "ok": true,
#   "time": "2024-XX-XXTXX:XX:XX.XXXZ",
#   "adminApi": true
# }

# Test with Invoke-WebRequest
$response = Invoke-WebRequest -Uri "http://localhost:3000/api/health"
$response.StatusCode
# Expected: 200
```

### Frontend Health Check

```powershell
# Test frontend
curl http://localhost:5555

# Expected: HTML content returned

# Test with Invoke-WebRequest
$response = Invoke-WebRequest -Uri "http://localhost:5555"
$response.StatusCode
# Expected: 200
```

### Smoke Tests

```powershell
# Run comprehensive smoke tests
.\smoke.ps1

# Expected:
# - All tests pass
# - Ports 3000, 5555 are listening
# - Health endpoints return 200
# - Auth endpoint returns 401 (correct without credentials)
```

### Manual UI Testing

1. **Open Frontend:**
   - Navigate to: http://localhost:5555
   - Expected: Login page displays

2. **Login:**
   - Email: `root@bn9.local`
   - Password: `bn9@12345`
   - Tenant: `bn9`
   - Expected: Login successful, redirects to dashboard

3. **Dashboard:**
   - Expected: Dashboard loads without errors
   - Check browser console: No critical errors

4. **API Calls:**
   - Check Network tab: API calls go to `/api/*`
   - Expected: Status 200 for successful calls

### Port Checks

```powershell
# Check ports are listening
Get-NetTCPConnection -LocalPort 3000 -State Listen
# Expected: Backend process

Get-NetTCPConnection -LocalPort 5555 -State Listen
# Expected: Frontend process

# Or with netstat
netstat -ano | findstr ":3000"
netstat -ano | findstr ":5555"
```

### Stop Services

```powershell
# Stop all services
.\stop-dev.ps1

# Expected:
# - Processes killed
# - Ports released

# Verify ports are free
Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
# Expected: No output (port free)
```

## 🐳 Docker Validation

### Docker Compose Check

```powershell
# Validate docker-compose.yml
docker-compose config
# Expected: Valid configuration shown

# Start all services
docker-compose up -d

# Check services
docker-compose ps
# Expected: All services running

# Check logs
docker-compose logs backend
docker-compose logs frontend

# Stop services
docker-compose down
```

### Individual Services

```powershell
# Test PostgreSQL
docker-compose up -d db
docker-compose logs db
# Expected: database system is ready to accept connections

# Test Redis
docker-compose up -d redis
docker-compose logs redis
# Expected: Ready to accept connections

# Test connection
redis-cli -p 6380 ping
# Expected: PONG
```

## 📝 Code Quality Validation

### Backend Code Quality

```powershell
cd bn88-backend-v12

# Type check
npm run typecheck
# Expected: No TypeScript errors

# Build
npm run build
# Expected: Successful build

# Run tests (if available)
npm test
# Expected: Tests pass
```

### Frontend Code Quality

```powershell
cd bn88-frontend-dashboard-v12

# Type check
npm run typecheck
# Expected: No TypeScript errors

# Lint
npm run lint
# Expected: No errors

# Format check
npm run format:check
# Expected: Code is formatted

# Build
npm run build
# Expected: Successful build

# Run tests (if available)
npm test
# Expected: Tests pass
```

## 🔒 Security Validation

### Environment Files

```powershell
# Check .env files are NOT in git
git status
git ls-files | Select-String ".env$"
# Expected: No .env files (only .env.example)

# Check .gitignore
Get-Content .gitignore | Select-String ".env"
# Expected: .env is ignored
```

### Secrets

```powershell
# Check no secrets in .env.example
Get-Content bn88-backend-v12/.env.example | Select-String "secret|password|token"
# Expected: Only default/placeholder values

# Verify JWT_SECRET is placeholder
Get-Content bn88-backend-v12/.env.example | Select-String "JWT_SECRET"
# Expected: JWT_SECRET=bn9_dev_secret_change_in_production
```

### Dependencies

```powershell
# Check for vulnerabilities (backend)
cd bn88-backend-v12
npm audit
# Review any HIGH or CRITICAL vulnerabilities

# Check for vulnerabilities (frontend)
cd ../bn88-frontend-dashboard-v12
npm audit
# Review any HIGH or CRITICAL vulnerabilities
```

## 📊 Performance Validation

### Backend Performance

```powershell
# Measure startup time
Measure-Command { 
  cd bn88-backend-v12
  npm run dev 
}

# Test API response time
Measure-Command { 
  curl http://localhost:3000/api/health 
}
# Expected: < 100ms for health check
```

### Frontend Performance

```powershell
# Measure build time
cd bn88-frontend-dashboard-v12
Measure-Command { npm run build }

# Check build size
Get-ChildItem dist -Recurse | Measure-Object -Property Length -Sum
# Expected: Reasonable size (< 5MB for main bundle)
```

## 🧩 Integration Validation

### Backend-Frontend Integration

```powershell
# 1. Start backend
cd bn88-backend-v12
npm run dev

# 2. Start frontend (different terminal)
cd bn88-frontend-dashboard-v12
npm run dev

# 3. Test login via UI
# Open http://localhost:5555
# Login with root@bn9.local / bn9@12345

# 4. Check API calls
# Open browser DevTools > Network
# See requests to /api/*
# Expected: Proxy working, 200 responses
```

### Database Integration

```powershell
# Test Prisma Studio
cd bn88-backend-v12
npm run studio
# Access http://localhost:5556

# Expected:
# - UI opens
# - Can view tables
# - Can see seeded data
```

## ✅ Final Validation Checklist

### Must Pass

- [ ] `npm install` works for backend
- [ ] `npm install` works for frontend
- [ ] Backend `.env.example` → `.env` created
- [ ] Frontend `.env.example` → `.env` created
- [ ] `npx prisma db push` succeeds
- [ ] `npm run seed:dev` succeeds
- [ ] Backend starts on port 3000
- [ ] Frontend starts on port 5555
- [ ] Health endpoint returns 200
- [ ] Login works with default credentials
- [ ] Dashboard loads after login
- [ ] Smoke tests pass

### Should Pass

- [ ] TypeScript compilation (backend)
- [ ] TypeScript compilation (frontend)
- [ ] Linting (frontend)
- [ ] Build (backend)
- [ ] Build (frontend)
- [ ] Docker compose up succeeds
- [ ] No critical npm audit issues
- [ ] Documentation is clear and helpful

### Nice to Have

- [ ] Tests pass
- [ ] No warnings in browser console
- [ ] Fast build times
- [ ] Small bundle sizes
- [ ] Good performance

## 🐛 Troubleshooting Validation Failures

### "Port already in use"

```powershell
.\stop-dev.ps1
# Or manually kill process
```

### "Cannot find module"

```powershell
rm -r node_modules
npm install
```

### "Prisma Client not initialized"

```powershell
npx prisma generate
```

### "Database connection failed"

```powershell
# Check DATABASE_URL in .env
# If Docker: docker-compose up -d db
# Test: npx prisma db push
```

### "Frontend can't reach backend"

1. Check backend is running: `curl http://localhost:3000/api/health`
2. Check proxy in `vite.config.ts`
3. Check CORS in backend `.env`

## 📈 Success Criteria

The project is fully validated when:

1. ✅ All "Must Pass" items complete
2. ✅ Smoke tests show 100% pass rate
3. ✅ Developer can clone and run in < 30 minutes
4. ✅ No blocker issues in documentation
5. ✅ Clean logs (no critical errors)

## 📚 Next Steps After Validation

1. **Development:** Start building features
2. **Customization:** Configure for your use case
3. **Deployment:** Follow production deployment guide
4. **Monitoring:** Setup logging and alerts
5. **Contributing:** See CONTRIBUTING.md

---

**Last Updated:** 2024-02-11

For questions, see [SETUP.md](SETUP.md) or create an issue.
