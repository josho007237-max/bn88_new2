# Dev Notes

## Deterministic dev auth flow (bn88-backend-v12)

```powershell
cd .\-bn88-new-clean-main\bn88-backend-v12
if (!(Test-Path .env)) { Copy-Item .env.example .env }
```

 codex/audit-and-fix-plan-for-bn88-backend-v12-f3hoo6
## REQUIRED: set `SECRET_ENC_KEY_BN9` (32 characters)
`SECRET_ENC_KEY_BN9` is required by `src/config.ts` (`z.string().length(32)`).

```powershell
# Option A: use the dev placeholder from .env.example (already 32 chars)
# SECRET_ENC_KEY_BN9=0123456789abcdef0123456789abcdef

# Option B: generate a new 32-char key with Node crypto
node -e "console.log(require('crypto').randomBytes(16).toString('hex'))"
```

=======
 main
### 1) Prepare DB schema
```powershell
npx prisma db push
```

### 2) Seed deterministic dev admin + RBAC
```powershell
npm run seed:dev
```

Defaults from `seedDev.ts`:
- email: `root@bn9.local`
- password: `bn9@12345`
- tenant: `bn9`
- RBAC: includes `manageBots`

### 3) Start backend
```powershell
npm run dev
```

### 4) Login + call `/api/admin/bots`

PowerShell (`irm`):
```powershell
$login = irm -Method Post -Uri "http://127.0.0.1:3000/api/admin/auth/login" -ContentType "application/json" -Body '{"email":"root@bn9.local","password":"bn9@12345"}'
$token = $login.token
irm -Method Get -Uri "http://127.0.0.1:3000/api/admin/bots" -Headers @{ Authorization = "Bearer $token"; "x-tenant" = "bn9" }
```

PowerShell (`curl.exe`):
```powershell
$token = (curl.exe -sS -X POST "http://127.0.0.1:3000/api/admin/auth/login" -H "Content-Type: application/json" -d '{"email":"root@bn9.local","password":"bn9@12345"}' | ConvertFrom-Json).token
curl.exe -sS "http://127.0.0.1:3000/api/admin/bots" -H "Authorization: Bearer $token" -H "x-tenant: bn9"
```


## Prisma CLI quick start (no manual env export)
```powershell
cd .\-bn88-new-clean-main\bn88-backend-v12
if (!(Test-Path .env)) { Copy-Item .env.example .env }
npx prisma db push
npx tsx src/scripts/seedDev.ts
```

Defaults from `seedDev.ts`:
- email: `root@bn9.local`
- password: `bn9@12345`
