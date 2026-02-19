# BN88 New Clean

BN88 เป็นโปรเจค full-stack สำหรับงาน LINE bot และ admin dashboard โดยแยกเป็น 3 ส่วนหลัก:

- `bn88-backend-v12`: Backend API (Node.js + Prisma)
- `bn88-frontend-dashboard-v12`: Frontend Dashboard (Vite + React)
- `line-engagement-platform`: LINE Engagement Platform (Express + Prisma + Redis)

## Quick Start (Local Dev)

1. ใช้ Node.js `18.x` (ดู `.nvmrc`)
2. สร้างไฟล์ `.env` จาก `.env.example` ในแต่ละโปรเจค
3. ติดตั้ง dependencies
4. เตรียมฐานข้อมูล backend (SQLite หรือ PostgreSQL)
5. รัน backend + frontend

### Windows (PowerShell)

```powershell
cd .\bn88-backend-v12
copy .env.example .env
npm install
npx prisma generate
npx prisma db push
npm run seed:dev

cd ..\bn88-frontend-dashboard-v12
copy .env.example .env
npm install

cd ..
.\start-dev.ps1
```

### Linux/macOS (bash)

```bash
cd ./bn88-backend-v12
cp .env.example .env
npm install
npx prisma generate
npx prisma db push
npm run seed:dev

cd ../bn88-frontend-dashboard-v12
cp .env.example .env
npm install

# รันคนละ terminal
cd ../bn88-backend-v12 && npm run dev
cd ../bn88-frontend-dashboard-v12 && npm run dev
```

## Default Ports

- Backend API: `http://localhost:3000` (local also reachable as `http://127.0.0.1:3000`)
- Frontend Dashboard: `http://localhost:5555` (local also reachable as `http://127.0.0.1:5555`)
- LINE Engagement Platform: `http://localhost:8080`

## Documentation

- คู่มือไทยติดตั้ง/รันแบบละเอียด: `docs/INSTALL-RUN-BN88-TH.md`
- Setup แบบย่อ: `SETUP.md`
- Runbook Local: `RUNBOOK-LOCAL.md`
- Runbook Operations: `RUNBOOK.md`

## Helper Scripts (Windows)

- `.\start-dev.ps1`: เปิด backend + frontend
- `.\stop-dev.ps1`: หยุด process ที่ใช้พอร์ต dev
- `.\smoke.ps1`: ตรวจสุขภาพระบบแบบรวดเร็ว

## Security Notes

- ห้ามคอมมิตไฟล์ `.env` หรือ secret ใด ๆ
- หมุน key/secret ทันทีหากสงสัยว่ามีการรั่วไหล
- ใช้ least-privilege สำหรับสิทธิ์ database และ token
