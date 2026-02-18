# RUNBOOK LOCAL (Windows / PowerShell)

โครงสร้าง repo นี้มีโค้ดหลักอยู่ใต้โฟลเดอร์ `-bn88-new-clean-main`.

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
