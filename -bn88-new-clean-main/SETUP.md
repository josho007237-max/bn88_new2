# BN88 Setup (First Time)

เอกสารนี้เป็นเวอร์ชันย่อสำหรับเริ่มใช้งานเร็ว  
คู่มือภาษาไทยแบบเต็มดูที่ `docs/INSTALL-RUN-BN88-TH.md`

## 1) Requirements

- Node.js `18.x`
- npm
- Docker / Docker Compose (optional)

ตรวจสอบเวอร์ชัน:

```bash
node -v
npm -v
```

## 2) Clone Repository

```bash
git clone <repository_url>
cd -bn88-new-clean-main
```

## 3) Backend Setup

### Windows (PowerShell)

```powershell
cd .\bn88-backend-v12
copy .env.example .env
npm install
npx prisma generate
npx prisma db push
npm run seed:dev
```

### Linux/macOS (bash)

```bash
cd ./bn88-backend-v12
cp .env.example .env
npm install
npx prisma generate
npx prisma db push
npm run seed:dev
```

## 4) Frontend Setup

### Windows (PowerShell)

```powershell
cd ..\bn88-frontend-dashboard-v12
copy .env.example .env
npm install
```

### Linux/macOS (bash)

```bash
cd ../bn88-frontend-dashboard-v12
cp .env.example .env
npm install
```

## 5) Start Services

### Windows (PowerShell)

```powershell
cd ..
.\start-dev.ps1
```

### Linux/macOS (bash)

```bash
cd ../bn88-backend-v12 && npm run dev
# อีก terminal
cd ../bn88-frontend-dashboard-v12 && npm run dev
```

## 6) Verify

- Backend: `http://localhost:3000/api/health`
- Frontend: `http://localhost:5555`

Windows สามารถใช้ smoke test:

```powershell
.\smoke.ps1
```

## 7) Optional: LINE Engagement Platform

```bash
cd line-engagement-platform
cp .env.example .env
npm install
npm run dev
```

หรือใช้ Docker Compose ของโฟลเดอร์ LEP:

```bash
cd line-engagement-platform
docker compose up -d --build
```

## Security

- ห้ามคอมมิต `.env`
- ใช้ค่า placeholder ในเอกสารเท่านั้น
- เปลี่ยน `JWT_SECRET` และรหัสผ่านเริ่มต้นก่อนใช้งานจริง
