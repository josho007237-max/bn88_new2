# BN9 Backend (v2)

## Dev
npm i
npx prisma migrate dev
npm run dev

## ENV
ดู .env.example แล้วคัดลอกเป็น .env

## Run cmds
cd bn88-backend-v12
npm i
npx prisma migrate dev
npm run dev
npm run smoke:ports

## Quick test (PowerShell)
netstat -ano | findstr :3000
irm http://127.0.0.1:3000/api/health
Test-NetConnection -ComputerName 127.0.0.1 -Port 6380
cloudflared tunnel --url http://127.0.0.1:3000
curl http://127.0.0.1:3000/api/health

## Troubleshooting
รันผิดโฟลเดอร์: cd bn88-backend-v12
พอร์ตชน: ปิดโปรเซสที่ใช้พอร์ตนั้นก่อน
ExecutionPolicy: ใช้ powershell -ExecutionPolicy Bypass

## Quick admin check (replace <TOKEN>)
```
curl -H "Authorization: Bearer <TOKEN>" -H "x-tenant: bn9" http://localhost:3000/api/admin/roles/permissions
curl -H "Authorization: Bearer <TOKEN>" -H "x-tenant: bn9" http://localhost:3000/api/admin/bots
```

## Login payload (must use email)
`POST /api/admin/auth/login` ต้องส่ง `email` + `password` (ไม่ใช่ `username`)

PowerShell (`irm`) example:
```powershell
$body = @{ email = "admin@bn9.local"; password = "admin123" } | ConvertTo-Json
$r = irm "http://127.0.0.1:3000/api/admin/auth/login" -Method POST -ContentType "application/json" -Headers @{ "x-tenant" = "bn9" } -Body $body
$r.token
```

## SSE auth (EventSource)
`GET /api/live/:tenant` accepts auth from these sources (priority order):
- `Authorization: Bearer <token>`
- query string (`?token=...` or `?access_token=...`)
- cookie `bn88_token`

Because browser `EventSource` cannot attach custom auth headers, frontend should open SSE with token in query:
```
new EventSource(`/api/live/${tenant}?token=${token}`)
```

cURL probe example:
```
curl -i -N "http://localhost:3000/api/live/bn9?token=<TOKEN>"
```

## Login + reuse token
```
TOKEN=$(curl -s -H "Content-Type: application/json" -H "x-tenant: bn9" \
  -d '{"email":"admin@example.com","password":"secret"}' \
  http://localhost:3000/admin/auth/login | jq -r '.token')
curl -H "Authorization: Bearer $TOKEN" -H "x-tenant: bn9" http://localhost:3000/api/admin/roles/permissions
```
