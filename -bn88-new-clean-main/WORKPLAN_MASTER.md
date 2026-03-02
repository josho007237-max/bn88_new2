# WORKPLAN_MASTER

เอกสารเดียวสำหรับ **Reset Book + Workplan** ของโปรเจกต์ `BN88-new-clean` โดยอิงจากโค้ดจริงใน monorepo และยึดหลัก **minimal diff**:
- ไม่เปลี่ยน API เดิม
- ไม่รื้อโครงสร้างใหญ่
- ทำทีละเฟสพร้อม acceptance ชัดเจน

---

## 1) Architecture (อิงโค้ดจริง)

### 1.1 LINE Inbound
1. รับ webhook ที่ `POST /api/webhooks/line` (รองรับ `/:tenant` และ `/:tenant/:botId`) จาก `src/server.ts` + `src/routes/webhooks/line.ts`
2. ตรวจ signature/resolve bot secret/token แล้วแปลง event
3. บันทึกข้อมูลสนทนาเข้า DB (`ChatSession`, `ChatMessage`)
4. broadcast เข้า SSE hub เพื่อให้หน้าแอดมินอัปเดตทันที

**ไฟล์หลัก**
- `bn88-backend-v12/src/server.ts`
- `bn88-backend-v12/src/routes/webhooks/line.ts`
- `bn88-backend-v12/src/services/inbound/processIncomingMessage.ts`
- `bn88-backend-v12/src/lib/sseHub.ts`

### 1.2 LINE/Admin Outbound
1. แอดมินตอบจาก Chat Center ที่ `POST /api/admin/chat/sessions/:id/reply`
2. Backend ส่งออกไป LINE (`/v2/bot/message/push`) หรือ Telegram ตาม platform
3. บันทึก `ChatMessage` ฝั่ง admin + อัปเดต `ChatSession` + broadcast SSE

**ไฟล์หลัก**
- `bn88-backend-v12/src/routes/admin/chat.ts`

### 1.3 DB Model ที่ใช้จริง (Chat Center)
- `ChatSession` เก็บห้องสนทนา (tenant/bot/platform/user/status/unread/lastMessage)
- `ChatMessage` เก็บข้อความในห้อง (sender/type/text/attachment/platformMessageId)
- ความสัมพันธ์หลัก: `ChatSession 1:N ChatMessage`

**ไฟล์หลัก**
- `bn88-backend-v12/prisma/schema.prisma`

### 1.4 SSE
- Backend เปิดสตรีมที่ `GET /api/live/:tenant` (authGuard)
- ใช้ singleton `sseHub` สำหรับ add client + heartbeat + broadcast
- Frontend subscribe ผ่าน EventSource

**ไฟล์หลัก**
- `bn88-backend-v12/src/server.ts`
- `bn88-backend-v12/src/lib/sseHub.ts`
- `bn88-frontend-dashboard-v12/src/lib/useSSE.ts`

### 1.5 Admin API
- เปิดใช้เมื่อ `ENABLE_ADMIN_API=1`
- public: `/api/admin/auth/*`
- protected: `/api/admin/chat`, `/api/admin/bots`, `/api/admin/roles`, `/api/admin/faq`, `/api/admin/ai/*` ฯลฯ

**ไฟล์หลัก**
- `bn88-backend-v12/src/server.ts`

---

## 2) Monorepo map

- `bn88-backend-v12` — API/Webhook/SSE/Prisma
- `bn88-frontend-dashboard-v12` — Dashboard React + API client + Chat Center UI
- `line-engagement-platform` — บริการ engagement แยก (Express/Prisma/Redis)

---

## 3) Ports / Endpoints ที่ใช้งานจริง

### 3.1 Ports
- Backend API: `http://localhost:3000`
- Frontend Dashboard (Vite): `http://localhost:5555`
- Line Engagement Platform: `http://localhost:8080`

### 3.2 Core endpoints
- Health: `GET /api/health`
- Admin login: `POST /api/admin/auth/login`
- Admin chat sessions: `GET /api/admin/chat/sessions`
- Admin chat messages: `GET /api/admin/chat/messages`
- Admin reply: `POST /api/admin/chat/sessions/:id/reply`
- SSE: `GET /api/live/:tenant`
- LINE webhook: `POST /api/webhooks/line`
- LINE media proxy: `GET /api/admin/chat/line-content/:id`
- LEP health: `GET /health` (service ที่พอร์ต 8080)

---

## 4) สถานะล่าสุด (Latest status)

- ✅ backend health = `200`
- ✅ admin login = `200`
- ✅ chat/sessions = `200`
- ℹ️ `items` ยังว่าง เพราะยังไม่มีข้อมูล `ChatSession` ในฐานข้อมูล

> สถานะนี้ถือเป็น baseline ปกติสำหรับระบบที่ยังไม่รับข้อความจริงจาก LINE/seed session

---

## 5) Phase 0–9+ (Checklist + Acceptance + PowerShell)

## Phase 0 — Bootstrap / Sanity
**Checklist**
- [ ] เปิด path repo ถูกต้อง
- [ ] ติดตั้ง dependencies ของทั้ง 3 โปรเจกต์
- [ ] ตรวจเวอร์ชัน Node/NPM พร้อมใช้งาน

**Acceptance criteria**
- เข้าถึงทุกโฟลเดอร์ใน monorepo ได้
- `npm install` ผ่านครบ

**PowerShell checks**
```powershell
cd C:\Go23_th\bn88_new2\-bn88-new-clean-main
git rev-parse --show-toplevel
npm -w bn88-backend-v12 -v
npm -w bn88-frontend-dashboard-v12 -v
npm -w line-engagement-platform -v
```

## Phase 1 — Backend baseline
**Checklist**
- [ ] backend start ได้
- [ ] health endpoint ตอบ

**Acceptance criteria**
- `GET /api/health` ต้องได้ `200` และ `ok=true`

**PowerShell checks**
```powershell
cd C:\Go23_th\bn88_new2\-bn88-new-clean-main\bn88-backend-v12
npm run dev
# terminal ใหม่
curl.exe -i http://localhost:3000/api/health
```

## Phase 2 — Admin auth baseline
**Checklist**
- [ ] login ได้ token
- [ ] เรียก admin endpoint ด้วย Bearer token ได้

**Acceptance criteria**
- `POST /api/admin/auth/login` = `200`
- `GET /api/admin/bots` = `200`

**PowerShell checks**
```powershell
$body = '{"email":"root@bn9.local","password":"bn9@12345"}'
curl.exe -i -X POST http://localhost:3000/api/admin/auth/login -H "Content-Type: application/json" -d $body
# นำ token ที่ได้ไปแทน <TOKEN>
curl.exe -i http://localhost:3000/api/admin/bots -H "Authorization: Bearer <TOKEN>" -H "x-tenant: bn9"
```

## Phase 3 — Chat sessions baseline
**Checklist**
- [ ] endpoint sessions ตอบ 200
- [ ] ยอมรับเคส `items=[]` ได้ (ยังไม่มี ChatSession)

**Acceptance criteria**
- `GET /api/admin/chat/sessions` = `200`
- response shape เป็น `{ ok:true, items:[...] }`

**PowerShell checks**
```powershell
curl.exe -i "http://localhost:3000/api/admin/chat/sessions?limit=5" -H "Authorization: Bearer <TOKEN>" -H "x-tenant: bn9"
```

## Phase 4 — SSE readiness
**Checklist**
- [ ] เปิด stream `/api/live/:tenant` ได้
- [ ] connection ไม่หลุดทันที

**Acceptance criteria**
- รับ `text/event-stream` ได้ต่อเนื่อง

**PowerShell checks**
```powershell
curl.exe -N "http://localhost:3000/api/live/bn9?token=<TOKEN>" -H "Accept: text/event-stream"
```

## Phase 5 — LINE inbound persistence
**Checklist**
- [ ] webhook route ตอบได้
- [ ] เมื่อมี event จริงแล้วเกิด ChatSession/ChatMessage

**Acceptance criteria**
- webhook ไม่ 500
- มี row ใน `ChatSession` และ `ChatMessage` หลังรับข้อความจริง

**PowerShell checks**
```powershell
curl.exe -i -X POST "http://localhost:3000/api/webhooks/line" -H "Content-Type: application/json" --data "{\"events\":[]}"
cd C:\Go23_th\bn88_new2\-bn88-new-clean-main\bn88-backend-v12
npx prisma studio
```

## Phase 6 — Admin outbound reply
**Checklist**
- [ ] reply endpoint ทำงาน
- [ ] มีบันทึกข้อความ admin ใน DB
- [ ] FE เห็นข้อความใหม่ผ่าน refresh/SSE

**Acceptance criteria**
- `POST /api/admin/chat/sessions/:id/reply` = `200`
- `chatMessage` ใหม่ถูกสร้าง

**PowerShell checks**
```powershell
$payload = '{"text":"hello from admin"}'
curl.exe -i -X POST "http://localhost:3000/api/admin/chat/sessions/<SESSION_ID>/reply" -H "Authorization: Bearer <TOKEN>" -H "x-tenant: bn9" -H "Content-Type: application/json" -d $payload
```

## Phase 7 — Media proxy (line-content)
**Checklist**
- [ ] line-content endpoint ใช้งานได้
- [ ] FE แสดงรูป/ดาวน์โหลดไฟล์ได้

**Acceptance criteria**
- `GET /api/admin/chat/line-content/:id` = `200` (เมื่อ id มีจริง)
- มี `Content-Type` ถูกต้อง

**PowerShell checks**
```powershell
curl.exe -i "http://localhost:3000/api/admin/chat/line-content/<MESSAGE_ID>" -H "Authorization: Bearer <TOKEN>" -H "x-tenant: bn9"
```

## Phase 8 — Frontend integration gate
**Checklist**
- [ ] dashboard login ได้
- [ ] หน้า Chat Center โหลด sessions/messages ได้
- [ ] SSE client เชื่อมต่อได้

**Acceptance criteria**
- FE dev server เปิดได้
- เรียก API หลักแล้วไม่ error blocking

**PowerShell checks**
```powershell
cd C:\Go23_th\bn88_new2\-bn88-new-clean-main\bn88-frontend-dashboard-v12
npm run dev
```

## Phase 9 — Regression smoke
**Checklist**
- [ ] smoke script backend ผ่าน
- [ ] auth/chat/sse เสถียร

**Acceptance criteria**
- smoke scripts ออกโค้ด 0

**PowerShell checks**
```powershell
cd C:\Go23_th\bn88_new2\-bn88-new-clean-main\bn88-backend-v12
pwsh -File .\scripts\smoke-all.ps1
pwsh -File .\scripts\p0-chat-smoke.ps1
```

## Phase 9+ — Hardening (ไม่เปลี่ยน API)
**Checklist**
- [ ] เพิ่ม integration tests ที่ขาด (auth/sse/webhook/chat)
- [ ] เพิ่ม observability/log correlation
- [ ] เติม seed หรือ simulator เพื่อสร้าง ChatSession อัตโนมัติใน dev

**Acceptance criteria**
- regression ลดลง, reproduce issue ได้ไวขึ้น
- API เดิมยังคงเดิมทั้งหมด

**PowerShell checks**
```powershell
cd C:\Go23_th\bn88_new2\-bn88-new-clean-main\bn88-backend-v12
npm test
npm run lint
```

---

## 6) Guardrails (ย้ำข้อกำหนด)

- ห้ามเปลี่ยน API path ที่ FE ใช้อยู่
- ห้าม refactor โครงสร้างใหญ่ในรอบนี้
- ทุกงานให้เป็น incremental, reversible, และ minimal diff
