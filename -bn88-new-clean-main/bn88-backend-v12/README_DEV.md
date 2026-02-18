# Dev Notes

## PowerShell-safe `curl.exe` (use backticks, not `^`)
```powershell
$TOKEN = "<JWT>"
curl.exe -sS `
  -H "Authorization: Bearer $TOKEN" `
  -H "x-tenant: bn9" `
  "http://127.0.0.1:3000/api/admin/roles/permissions"
```

## `ripgrep` with `-F` (fixed string, no regex differences)
```powershell
rg -n -F "requirePermission([\"manageBots\"])" src
rg -n -F "/api/admin/chat/line-content" src
rg -n -F "SECRET_ENC_KEY_BN9" .env .env.example
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
