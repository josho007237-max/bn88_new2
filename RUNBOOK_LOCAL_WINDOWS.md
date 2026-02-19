# RUNBOOK LOCAL (Windows / PowerShell)

โครงสร้าง repo นี้มีโค้ดหลักอยู่ใต้โฟลเดอร์ `-bn88-new-clean-main`.

## 0) แก้ปัญหา ENOENT ตอน `npm run dev` (อยู่ผิดโฟลเดอร์)

```powershell
cd C:\Go23_th\bn88_new2\-bn88-new-clean-main\bn88-frontend-dashboard-v12
Test-Path .\package.json
npm run dev
```

## 1) ไปที่ backend ให้ถูก path

```powershell
cd /path/to/bn88_new2
cd .\-bn88-new-clean-main\bn88-backend-v12
```

หรือใช้สคริปต์จาก repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\p0-jump-backend.ps1
```

## 2) ตรวจ auth guard / permission ด้วย `rg -F`

```powershell
rg --line-number --no-heading -F "authGuard(" .\src
rg --line-number --no-heading -F "requirePermission(" .\src
```

## 3) สรุป mount points ใน `src/server.ts`

```powershell
Select-String -Path .\src\server.ts -Pattern '/api/webhooks|/api/admin'
```

## 4) คำสั่งเร็ว (copy-paste)

### 4.1 รัน 2 สคริปต์ต่อกัน (จาก repo root)

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
$hit = (& .\scripts\p0-find-backend.ps1 | Select-String -Pattern "bn88-backend-v12" | Select-Object -First 1).Line.Trim()
# ถ้าไม่อยาก parse output: ให้ copy path จาก p0-find-backend แล้ว set $backend เอง
Write-Host "HINT: copy backend path from output แล้วตั้ง `$backend=..." -ForegroundColor Yellow
```

### 4.2 เช็ค /api/admin และ ENABLE_ADMIN_API แบบเร็ว

```powershell
$backend="C:\Go23_th\bn88_new2\-bn88-new-clean-main\bn88-backend-v12"
rg -n -S -F "/api/admin" "$backend\src\server.ts"
rg -n -S -F "ENABLE_ADMIN_API" "$backend\src\server.ts"
```


## 5) Tunnel/API smoke (Windows)

### 5.1 ใช้ `rg` หาไฟล์ที่ต้องแก้ (API_BASE / SSE / cloudflared)

```powershell
rg -n -S "VITE_API_BASE|VITE_ADMIN_API_BASE|API_BASE" .\-bn88-new-clean-main\bn88-frontend-dashboard-v12\src .\-bn88-new-clean-main\bn88-frontend-dashboard-v12\.env.example
rg -n -S "/api/live|EventSource|token=" .\-bn88-new-clean-main\bn88-frontend-dashboard-v12\src
rg -n -S "cloudflared.*loglevel|tunnel --config|--ssl-no-revoke|SkipCertificateCheck" .\run-kumphan-bn9.ps1 .\-bn88-new-clean-main\run-tunnel.ps1
```

### 5.2 ทดสอบ health ผ่านโดเมนจริง (แก้ Schannel revocation)

```powershell
curl.exe -i --ssl-no-revoke https://api.bn9.app/api/health
curl.exe -i -k https://api.bn9.app/api/health
irm https://api.bn9.app/api/health -SkipCertificateCheck
```

### 5.3 รัน cloudflared debug (flag ตำแหน่งถูกต้อง)

```powershell
cloudflared --loglevel debug tunnel --config "$env:USERPROFILE\.cloudflared\config.yml" run bn88-api
```

## 6) ตรวจ repo + diff ให้ถูกต้อง (Windows PowerShell)

เป้าหมาย: ตรวจว่าแก้ไฟล์ `bn88-frontend-dashboard-v12/src/lib/api.ts` (เช่น เพิ่ม `getLineContentPath`) แสดงใน `git diff` จริง

```powershell
# 1) เข้าโฟลเดอร์โปรเจกต์ที่ถูกต้อง
cd C:\Go23_th\bn88_new2\-bn88-new-clean-main

# 2) ตรวจ git root และสถานะ branch แบบสั้น
git rev-parse --show-toplevel
git status -sb

# 3) ดู diff เฉพาะไฟล์ api.ts
git diff -- .\bn88-frontend-dashboard-v12\src\lib\api.ts
```

> หมายเหตุสำคัญ: ถ้าตอนนี้อยู่ในโฟลเดอร์ FE (`...\bn88-frontend-dashboard-v12`) แล้วใช้ `Split-Path` ถอย 2 ชั้น มักจะหลุดไป `bn88_new2` (ผิดตำแหน่ง) ให้ใช้ `cd ..` ถอย 1 ชั้นไป `-bn88-new-clean-main` หรือ `cd` ด้วย full path ตามตัวอย่างด้านบนแทน

## 7) แก้ปัญหา esbuild หาไฟล์ `./src/lib/api.ts` ไม่เจอ (รันจากโฟลเดอร์ผิด)

ถ้าเจอ error `Could not resolve .\src\lib\api.ts` มักเกิดจากรันคำสั่งจาก `C:\Go23_th\bn88_new2` แทนที่จะอยู่ในโฟลเดอร์ FE

```powershell
# 1) เข้าโฟลเดอร์ FE ให้ถูกต้อง
cd C:\Go23_th\bn88_new2\-bn88-new-clean-main\bn88-frontend-dashboard-v12

# 2) เช็คไฟล์สำคัญ ต้องได้ True ทั้งคู่
Test-Path .\src\lib\api.ts
Test-Path .\package.json

# 3) ทดสอบ esbuild (ไฟล์เป้าหมายตรง)
npx esbuild .\src\lib\api.ts --loader:.ts=ts --log-level=error --outfile=.\.tmp-api.js

# 4) ทดสอบ TypeScript
npx tsc -p tsconfig.json --noEmit

# 5) รัน dev server
npm run dev
```

> หมายเหตุ: ข้อความเตือน `baseline-browser-mapping` outdated เป็น warning ไม่ใช่ blocker; ถ้าต้องการค่อยอัปเดต dev dependency ภายหลัง

