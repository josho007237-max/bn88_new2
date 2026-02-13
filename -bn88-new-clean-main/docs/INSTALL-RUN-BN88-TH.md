# คู่มือติดตั้งและรันโปรเจค BN88 (ฉบับไทย)

เอกสารนี้อ้างอิงจากโครงสร้างและสคริปต์จริงใน repository ปัจจุบัน โดยครอบคลุม:

- Backend: `bn88-backend-v12` (Node.js + Prisma)
- Frontend: `bn88-frontend-dashboard-v12` (Vite + React)
- LINE Engagement Platform: `line-engagement-platform`
- Docker Compose, CI/CD, Checklist และ Security

## 1) ภาพรวมโครงสร้างโปรเจค

```text
-bn88-new-clean-main/
  ├─ bn88-backend-v12/
  ├─ bn88-frontend-dashboard-v12/
  ├─ line-engagement-platform/
  ├─ docs/
  ├─ start-dev.ps1
  ├─ stop-dev.ps1
  ├─ smoke.ps1
  └─ docker-compose.yml
```

## 2) เครื่องมือและสิทธิ์ที่ต้องใช้

- Node.js `18.x` (ไฟล์ `.nvmrc` ระบุ `18`)
- npm
- Prisma CLI:
  - แนะนำใช้ผ่าน `npx prisma ...` (ไม่บังคับติดตั้ง global)
  - ติดตั้ง global ได้ถ้าต้องการ: `npm i -g prisma`
- Docker / Docker Compose (optional แต่แนะนำถ้าต้องใช้ PostgreSQL/Redis)
- สิทธิ์สำหรับตั้งค่าไฟล์ `.env` และ secrets ต่าง ๆ

## 3) พอร์ตที่ใช้งานในระบบนี้ (ค่าเริ่มต้น)

- Backend: `3000`
- Frontend: `5555`
- LINE Engagement Platform (LEP): `8080`
- Redis (root compose): host `6380` -> container `6379`
- Redis (LEP standalone compose): host `6379` -> container `6379`
- PostgreSQL: `5432`

## 4) ขั้นตอนติดตั้ง (Windows PowerShell)

```powershell
git clone <repository_url>
cd .\-bn88-new-clean-main

# Backend
cd .\bn88-backend-v12
copy .env.example .env
npm install
npx prisma generate
npx prisma db push
npm run seed:dev

# Frontend
cd ..\bn88-frontend-dashboard-v12
copy .env.example .env
npm install

# (Optional) LINE platform
cd ..\line-engagement-platform
copy .env.example .env
npm install
```

รัน backend + frontend พร้อมกัน:

```powershell
cd ..
.\start-dev.ps1
```

หรือรันแยกเอง:

```powershell
cd .\bn88-backend-v12; npm run dev
cd ..\bn88-frontend-dashboard-v12; npm run dev
```

รัน LEP:

```powershell
cd .\line-engagement-platform
npm run dev
# หรือแบบ production-like
npm run build
npm run start
```

## 5) ขั้นตอนติดตั้ง (Linux/macOS)

```bash
git clone <repository_url>
cd ./-bn88-new-clean-main

# Backend
cd ./bn88-backend-v12
cp .env.example .env
npm install
npx prisma generate
npx prisma db push
npm run seed:dev

# Frontend
cd ../bn88-frontend-dashboard-v12
cp .env.example .env
npm install

# Optional: LEP
cd ../line-engagement-platform
cp .env.example .env
npm install
```

รัน backend/frontend (คนละ terminal):

```bash
cd ./bn88-backend-v12 && npm run dev
cd ./bn88-frontend-dashboard-v12 && npm run dev
```

รัน LEP:

```bash
cd ./line-engagement-platform
npm run dev
# หรือ production-like
npm run build && npm run start
```

## 6) ตัวอย่างไฟล์ `.env` (placeholder เท่านั้น)

หมายเหตุ:

- ใช้ค่า placeholder เท่านั้น ห้ามวาง secret จริงในเอกสาร
- ให้คัดลอกจาก `.env.example` ของแต่ละโฟลเดอร์แล้วแก้ค่าตามสภาพแวดล้อมจริง

### 6.1 Backend (`bn88-backend-v12/.env`)

```dotenv
NODE_ENV=development
PORT=3000

# เลือกแบบใดแบบหนึ่ง
DATABASE_URL=file:./prisma/dev.db
# DATABASE_URL=postgresql://<user>:<password>@localhost:5432/bn88?schema=public

APP_BASE_URL=http://localhost:3000
WEBHOOK_BASE_URL=http://localhost:3000
API_BASE_URL=http://localhost:3000

JWT_SECRET=<change_me>
JWT_EXPIRE=7d
SECRET_ENC_KEY_BN9=<32_characters>

REDIS_URL=redis://127.0.0.1:6380
REDIS_HOST=127.0.0.1
REDIS_PORT=6380

LINE_CHANNEL_SECRET=<line_secret>
LINE_CHANNEL_ACCESS_TOKEN=<line_access_token>
OPENAI_API_KEY=<openai_key>
```

### 6.2 Frontend (`bn88-frontend-dashboard-v12/.env`)

```dotenv
VITE_API_BASE=http://127.0.0.1:3000/api
VITE_ADMIN_API_BASE=http://127.0.0.1:3000/api
VITE_API_BASE_URL=http://127.0.0.1:3000
VITE_TENANT=bn9
VITE_DEFAULT_TENANT=bn9
VITE_DEFAULT_BOT_ID=dev-bot
VITE_APP_VERSION=dev
```

### 6.3 LINE Platform (`line-engagement-platform/.env`)

```dotenv
PORT=8080
BASE_URL=http://localhost:8080

DATABASE_URL=postgresql://postgres:postgres@postgres:5432/line_platform
REDIS_URL=redis://redis:6379
REDIS_HOST=redis
REDIS_PORT=6379
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=postgres
PRISMA_MIGRATE_MODE=deploy

LINE_CHANNEL_SECRET=<line_secret>
LINE_CHANNEL_ACCESS_TOKEN=<line_access_token>

LINE_LOGIN_CHANNEL_ID=<line_login_id>
LINE_LOGIN_CHANNEL_SECRET=<line_login_secret>
LINE_LOGIN_REDIRECT_URI=http://localhost:8080/auth/callback

LIFF_APP_ID=<liff_app_id>
LINE_PAY_BASE=https://sandbox-api-pay.line.me
LINE_PAY_CHANNEL_ID=<line_pay_id>
LINE_PAY_CHANNEL_SECRET=<line_pay_secret>
LINE_PAY_CONFIRM_URL=http://localhost:8080/payment/confirm

ADS_ACCESS_TOKEN=<line_ads_token>
BULL_BOARD_USER=admin
BULL_BOARD_PASS=<change_me>
WORKER_CONCURRENCY=5
WORKER_RATE_MAX=10
WORKER_RATE_DURATION_MS=1000
NODE_ENV=development
```

## 7) โหมดฐานข้อมูลและ Docker Compose

## 7.1 โหมดเร็ว (Backend SQLite)

- ตั้ง `DATABASE_URL=file:./prisma/dev.db` ใน backend
- ใช้คำสั่ง:

```bash
cd bn88-backend-v12
npx prisma generate
npx prisma db push
npm run seed:dev
```

## 7.2 โหมด PostgreSQL/Redis ผ่าน root compose

ไฟล์: `docker-compose.yml` (root)

- มี service หลัก: `db`, `lep_db`, `redis`, `backend`, `frontend`, `lep`
- Redis ของ root compose เปิดที่ host `6380`
- ถ้า backend ใช้ compose network:
  - DB host จะเป็น `db`
  - Redis host จะเป็น `redis`
- ถ้ารัน backend บนเครื่อง host:
  - DB/Redis ควรชี้ `localhost` ตาม port ที่เปิด

คำสั่ง:

```bash
docker compose up -d
# หรือบางเครื่อง
docker-compose up -d
```

## 7.3 โหมด LEP standalone compose

ไฟล์: `line-engagement-platform/docker-compose.yml`

- service หลัก: `postgres`, `redis`, `app`, `worker`
- ในไฟล์ `.env` ของ LEP ตัวอย่างใช้ host เป็น `postgres` และ `redis`
- ถ้ารัน LEP แบบไม่ผ่าน compose ให้เปลี่ยน host ใน `.env` เป็น `localhost`

คำสั่ง:

```bash
cd line-engagement-platform
docker compose up -d --build
```

## 8) Prisma / Migration Matrix

| พื้นที่ | กรณีใช้งาน | คำสั่ง |
|---|---|---|
| Backend | เตรียม dev db (ครั้งแรก) | `npx prisma generate && npx prisma db push && npm run seed:dev` |
| Backend | มี schema เปลี่ยนและต้องสร้าง migration | `npx prisma migrate dev --name <migration_name>` |
| Backend | deploy/CI | `npx prisma migrate deploy` |
| LEP | dev migration script | `npm run prisma:migrate` |
| LEP | deploy/CI | `npx prisma migrate deploy` |

## 9) คำสั่งรันแอปหลัก

### Backend

```bash
cd bn88-backend-v12
npm run dev
```

### Frontend

```bash
cd bn88-frontend-dashboard-v12
npm run dev
```

### LINE Platform

```bash
cd line-engagement-platform
npm run dev
# หรือ
npm run build && npm run start
```

### Root helper scripts (Windows)

```powershell
.\start-dev.ps1
.\stop-dev.ps1
.\smoke.ps1
```

## 10) CI/CD (อ้างอิง workflow ปัจจุบัน)

ไฟล์จริง: `.github/workflows/ci.yml`

สิ่งที่ workflow ปัจจุบันทำ:

- ใช้ Node.js `18`
- แยก jobs เป็น:
  - `backend` (install, build, test)
  - `frontend` (install, build, test)
  - `prisma-validate`
  - `integration`

ตัวอย่าง job เสริม (optional) สำหรับ `line-engagement-platform`:

```yaml
line-platform:
  name: LINE Platform Build
  runs-on: ubuntu-latest
  defaults:
    run:
      working-directory: line-engagement-platform
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: 18
        cache: npm
        cache-dependency-path: line-engagement-platform/package-lock.json
    - run: npm ci
    - run: npx prisma migrate deploy
      env:
        DATABASE_URL: postgresql://postgres:postgres@localhost:5432/line_platform
    - run: npm run build
```

## 11) ตารางสรุปคำสั่งสำคัญ

| งาน | คำสั่ง |
|---|---|
| ตรวจ Node/NPM | `node -v && npm -v` |
| ติดตั้ง backend deps | `cd bn88-backend-v12 && npm install` |
| ติดตั้ง frontend deps | `cd bn88-frontend-dashboard-v12 && npm install` |
| ติดตั้ง LEP deps | `cd line-engagement-platform && npm install` |
| backend db init (dev) | `npx prisma generate && npx prisma db push && npm run seed:dev` |
| backend migrate dev | `npx prisma migrate dev --name <name>` |
| migrate deploy | `npx prisma migrate deploy` |
| รัน backend | `npm run dev` |
| รัน frontend | `npm run dev` |
| รัน LEP dev | `npm run dev` |
| build backend | `npm run build` |
| build frontend | `npm run build` |
| build LEP | `npm run build` |
| compose up | `docker compose up -d` |
| compose down | `docker compose down` |
| smoke test (Windows) | `.\smoke.ps1` |

## 12) Mermaid Flowchart

```mermaid
flowchart LR
  A[ติดตั้ง Node.js 18 และ Docker (optional)] --> B[Clone Repository]
  B --> C[สร้างไฟล์ .env จาก .env.example]
  C --> D[ติดตั้ง dependencies ทุกโปรเจค]
  D --> E[เลือกโหมดฐานข้อมูล: SQLite หรือ Docker Compose]
  E --> F[รัน Prisma generate/db push/migrate]
  F --> G[เริ่ม Backend :3000]
  F --> H[เริ่ม Frontend :5555]
  F --> I[เริ่ม LEP :8080]
  G --> J[ตรวจ health + smoke test]
  H --> J
  I --> J
```

## 13) Checklist ก่อนรัน (Pre-run)

- ติดตั้ง Node.js `18.x` แล้ว (`node -v`)
- คัดลอก `.env.example` -> `.env` ครบทุกโปรเจค
- ใส่ค่า secrets จริงเฉพาะในเครื่อง/secret manager (ไม่ใส่ในเอกสาร)
- เลือกโหมด DB และตั้ง `DATABASE_URL` ให้ตรง
- รันคำสั่ง Prisma ตามโหมดที่ใช้
- ตรวจพอร์ตที่ต้องใช้ (`3000`, `5555`, `8080`, DB/Redis)
- ถ้าใช้ Windows script ให้ทดสอบ `.\start-dev.ps1` และ `.\smoke.ps1`

## 14) Security Checklist

- ห้ามคอมมิต `.env` หรือ token/key/password ลง Git
- ตรวจ `.gitignore` ว่าครอบคลุม `.env`, `.env.*`, DB/cache/build output
- หากคีย์รั่ว ให้หมุน secret ทันที
- จำกัดสิทธิ์ของ DB/Redis/API token ตามหลัก least-privilege
- เปลี่ยนค่าเริ่มต้นเช่น `JWT_SECRET`, `ADMIN_PASSWORD`, `BULL_BOARD_PASS` ก่อนใช้งานจริง
- ตรวจ CI/CD logs ว่าไม่พิมพ์ secret ออก console

## 15) หมายเหตุความสอดคล้องกับ repo ปัจจุบัน

- Node เวอร์ชันมาตรฐาน: `18`
- Frontend dev port: `5555` (ไม่ใช่ `5173`)
- Backend port: `3000`
- LEP port: `8080`
- Frontend env ใช้ตระกูล `VITE_API_BASE` / `VITE_ADMIN_API_BASE`

