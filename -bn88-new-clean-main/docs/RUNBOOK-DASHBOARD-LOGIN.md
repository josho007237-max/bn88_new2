# Runbook: Dashboard Login (Local)

## 1) Start Redis
```powershell
docker run --name bn88-redis --rm -p 6380:6379 redis:8-alpine
```

## 2) Start Backend
```powershell
cd .\bn88-backend-v12
npm i
npx prisma db push
npm run seed:dev
npm run dev
```

## 3) Start Dashboard
```powershell
cd .\bn88-frontend-dashboard-v12
npm i
npm run dev
```

## 4) Prisma Studio
```powershell
cd .\bn88-backend-v12
npm run studio
```

## 5) Test login (PowerShell `irm`)
```powershell
$body = @{
  email = "admin@bn9.local"
  password = "admin123"
} | ConvertTo-Json

$r = irm "http://127.0.0.1:3000/api/admin/auth/login" `
  -Method POST `
  -ContentType "application/json" `
  -Headers @{ "x-tenant" = "bn9" } `
  -Body $body

$token = $r.token
irm "http://127.0.0.1:3000/api/admin/bots" `
  -Headers @{
    Authorization = "Bearer $token"
    "x-tenant" = "bn9"
  }
```
