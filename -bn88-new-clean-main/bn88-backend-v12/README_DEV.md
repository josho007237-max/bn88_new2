# Dev Notes

## Deterministic dev auth flow (`bn88-backend-v12`)

### 0) Confirm you're in the correct project folder
```powershell
cd .\-bn88-new-clean-main\bn88-backend-v12
if (!(Test-Path .\package.json)) { throw "package.json not found - wrong folder" }
if ((Get-Content .\package.json -Raw) -notmatch '"name"\s*:\s*"bn88-backend-v12"') { throw "wrong package name - expected bn88-backend-v12" }
```

### 1) Create `.env` if missing
```powershell
if (!(Test-Path .env)) { Copy-Item .env.example .env }
```

### REQUIRED: set `SECRET_ENC_KEY_BN9` (32 characters)
`SECRET_ENC_KEY_BN9` is required by `src/config.ts` (`z.string().length(32)`).

```powershell
# Option A: use the dev placeholder from .env.example (already 32 chars)
# SECRET_ENC_KEY_BN9=0123456789abcdef0123456789abcdef

# Option B: generate a new 32-char key with Node crypto
node -e "console.log(require('crypto').randomBytes(16).toString('hex'))"
```

### 2) Quick env checks (safe in PowerShell)

Verify `dotenv` resolves from the backend folder:
```powershell
node -e "console.log(require.resolve('dotenv'))"
```

Verify required keys exist (without dotenv):
```powershell
Get-Content .env | Select-String '^SECRET_ENC_KEY_BN9='
Get-Content .env | Select-String '^ENABLE_ADMIN_API='
Get-Content .env | Select-String '^ENABLE_DEV_ROUTES='
```

### 3) Prepare DB schema
```powershell
npx prisma db push
```

### 4) Seed deterministic dev admin + RBAC
```powershell
npm run seed:dev
```

Defaults from `seedDev.ts`:
- email: `root@bn9.local`
- password: `bn9@12345`
- tenant: `bn9`
- RBAC: includes `manageBots`

### 5) Start backend
```powershell
npm run dev
```

### 6) Health check
```powershell
irm -Method Get -Uri "http://127.0.0.1:3000/api/health"
```

### 7) Login + call `/api/admin/bots`

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
