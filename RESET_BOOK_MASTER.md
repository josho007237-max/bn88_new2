# RESET_BOOK_MASTER

เอกสารนี้สรุปภาพรวม monorepo `-bn88-new-clean-main` สำหรับรีเซ็ตบริบทงาน (backend + frontend) โดย **ไม่เปลี่ยน API path** และไม่รื้อโครงสร้าง.

## 1) Monorepo map + critical files

## 1.1 Root map (สั้น กระชับ)

- `-bn88-new-clean-main/bn88-backend-v12` — API, webhook, SSE, Prisma
- `-bn88-new-clean-main/bn88-frontend-dashboard-v12` — Dashboard (Vite + React + TS)
- `-bn88-new-clean-main/WORKPLAN_MASTER.md` — แผนงาน/validation matrix เดิม
- `-bn88-new-clean-main/RUNBOOK.md` — runbook กลาง

## 1.2 Backend critical files

- `bn88-backend-v12/src/server.ts`
  - จุด mount route หลัก (`/api/health`, `/api/live/:tenant`, `/api/webhooks/line`, `/api/admin/*`)
- `bn88-backend-v12/src/routes/admin/*`
  - กลุ่ม admin auth/bots/chat/roles/knowledge/lep ฯลฯ
- `bn88-backend-v12/src/routes/webhooks/line.ts`
  - รับ LINE webhook inbound + dedupe + map message + emit event
- `bn88-backend-v12/src/lib/sseHub.ts`
  - hub สำหรับ broadcast เหตุการณ์ไป SSE clients
- `bn88-backend-v12/prisma/schema.prisma`
  - โครงสร้างข้อมูลหลัก โดยเฉพาะ `ChatSession` / `ChatMessage`

## 1.3 Frontend critical files

- `bn88-frontend-dashboard-v12/src/pages/ChatCenter.tsx`
  - หน้าจอ Chat Center, โหลด sessions/messages, ตอบแชต, แสดง media
- `bn88-frontend-dashboard-v12/src/lib/api.ts`
  - API client ทั้งหมดของ dashboard รวม chat endpoints + line-content helper

## 2) Architecture flows

## 2.1 LINE inbound flow

1. LINE ส่ง webhook เข้า `POST /api/webhooks/line`.
2. Backend route `routes/webhooks/line.ts` ตรวจ signature / resolve bot / กันซ้ำ event.
3. บันทึกข้อมูลสนทนาเข้า DB (`ChatSession`, `ChatMessage`).
4. Broadcast ผ่าน `sseHub` ไปยังผู้ดูแลที่เปิด Chat Center ผ่าน `/api/live/:tenant`.

## 2.2 Admin outbound reply flow

1. แอดมินส่ง reply จาก Chat Center → `POST /api/admin/chat/sessions/:id/reply`.
2. Backend `routes/admin/chat.ts` ส่งออกไป platform (เช่น LINE push API).
3. บันทึก `ChatMessage` ฝั่ง admin/bot ลง DB.
4. กระจายผลลัพธ์กลับผ่าน SSE ให้หน้าจออัปเดตทันที.

## 2.3 Media (LINE content) flow

1. FE ใช้ `getLineContentUrl`/blob helpers ใน `src/lib/api.ts`.
2. เรียก `GET /api/admin/chat/line-content/:id`.
3. Backend proxy ไป LINE content API ด้วย channel token แล้ว stream กลับ.

## 2.4 Data model flow (DB)

- `ChatSession`: ห้องสนทนา (tenant/bot/platform/user, status, unread, lastMessageAt)
- `ChatMessage`: ข้อความในห้อง (senderType/type/text/attachment/platformMessageId)
- ความสัมพันธ์หลัก: `ChatSession 1..n ChatMessage`

## 3) Ports & endpoints (baseline)

> พอร์ตหลัก backend: `3000` (ตาม runbook/workplan เดิม)

- Health
  - `GET /api/health`
- Admin auth
  - `POST /api/admin/auth/login`
- Admin bots
  - `GET /api/admin/bots`
- SSE
  - `GET /api/live/:tenant`
- LINE webhook
  - `POST /api/webhooks/line`
- LINE media proxy
  - `GET /api/admin/chat/line-content/:id`

## 4) Current status (Done / Doing / Blocked)

สรุปจากหลักฐานใน workplan/log ล่าสุดที่ใช้อ้างอิงงานรีเซ็ตบริบท:

- **Done**
  - Domain/API health ผ่าน (health ตอบ 200 ในชุดตรวจเดิม)
  - Admin login + bots endpoint ใช้งานได้ใน smoke/checklist เดิม
- **Doing**
  - Regression hardening ต่อเนื่อง (SSE, webhook dedupe, line-content acceptance ครบทุกเคส)
- **Blocked**
  - Frontend build/runtime ถูกบล็อกจาก error ซ้ำ `getLineContentPath` ใน `src/lib/api.ts` (ตามรายงาน Problems/esbuild/tsserver cache รอบล่าสุด)

> หมายเหตุ: ถ้า `npx tsc -p tsconfig.json --noEmit` ผ่านแล้ว แต่ VS Code ยังขึ้น error เดิม ให้ถือเป็น tsserver/IDE cache และทำ Restart TS Server + Reload Window ก่อนสรุปผลใหม่.

## 5) Master worklist (Phase 0–9+)

แต่ละ phase ระบุเป้าหมาย + acceptance command ที่รันซ้ำได้ทันที.

## Phase 0 — Bootstrap & repo sanity

- Goal: เข้าโฟลเดอร์ถูก + dependency พร้อม
- Acceptance:
  - `cd C:\Go23_th\bn88_new2\-bn88-new-clean-main`
  - `git rev-parse --show-toplevel`
  - `npm -w bn88-backend-v12 -v`
  - `npm -w bn88-frontend-dashboard-v12 -v`

## Phase 1 — Backend health baseline

- Goal: backend ตอบ health ได้สม่ำเสมอ
- Acceptance:
  - `curl.exe -i http://localhost:3000/api/health`

## Phase 2 — Admin auth + bots baseline

- Goal: login สำเร็จและเข้าถึง bots ด้วย token
- Acceptance:
  - `curl.exe -i -X POST http://localhost:3000/api/admin/auth/login -H "Content-Type: application/json" -H "x-tenant: bn9" --data "{\"email\":\"admin@example.com\",\"password\":\"secret\"}"`
  - `curl.exe -i http://localhost:3000/api/admin/bots -H "Authorization: Bearer <TOKEN>" -H "x-tenant: bn9"`

## Phase 3 — SSE path

- Goal: `/api/live/:tenant` เปิด stream ได้
- Acceptance:
  - `curl.exe -N "http://localhost:3000/api/live/bn9?token=<TOKEN>" -H "Accept: text/event-stream"`

## Phase 4 — LINE webhook inbound

- Goal: route webhook รับ payload ได้ + ตรวจ signature
- Acceptance:
  - `curl.exe -i -X POST "http://localhost:3000/api/webhooks/line?tenant=bn9&botId=<BOT_ID>" -H "Content-Type: application/json" --data "{\"events\":[]}"`
  - `rg -n "verifyLineSignature|dedupe|WebhookEvent" bn88-backend-v12/src/routes/webhooks/line.ts`

## Phase 5 — DB persistence (ChatSession/ChatMessage)

- Goal: schema/relations รองรับ chat center ครบ
- Acceptance:
  - `rg -n "model ChatSession|model ChatMessage" bn88-backend-v12/prisma/schema.prisma`
  - `npx prisma -C bn88-backend-v12 validate`

## Phase 6 — Admin reply outbound + SSE broadcast

- Goal: admin reply ส่งออก platform และ FE เห็น realtime
- Acceptance:
  - `rg -n "sessions/:id/reply|LINE push|sseHub.broadcast" bn88-backend-v12/src/routes/admin/chat.ts`
  - `rg -n "replyChatSession|getChatMessages|getChatSessions" bn88-frontend-dashboard-v12/src/lib/api.ts bn88-frontend-dashboard-v12/src/pages/ChatCenter.tsx`

## Phase 7 — Line-content proxy + FE media render

- Goal: ดาวน์โหลด/พรีวิวรูปจาก `/api/admin/chat/line-content/:id`
- Acceptance:
  - `curl.exe -i "http://localhost:3000/api/admin/chat/line-content/<MESSAGE_ID>?token=<TOKEN>&tenant=bn9"`
  - `rg -n "line-content/:id|getLineContentUrl|getLineContentBlob|fetchLineContentObjectUrl" bn88-backend-v12/src/routes/admin/chat.ts bn88-frontend-dashboard-v12/src/lib/api.ts`

## Phase 8 — FE compile/dev gate

- Goal: FE ผ่าน tsc/esbuild/dev
- Acceptance:
  - `cd C:\Go23_th\bn88_new2\-bn88-new-clean-main\bn88-frontend-dashboard-v12`
  - `npx tsc -p tsconfig.json --noEmit`
  - `npx esbuild .\src\lib\api.ts --loader:.ts=ts --log-level=error --outfile=.\.tmp-api.js`
  - `npm run dev`

## Phase 9 — Regression pack (auth/SSE/webhook/media)

- Goal: ปิด regression หลักก่อน deploy
- Acceptance:
  - `pwsh -File .\bn88-backend-v12\scripts\p0-smoke.ps1`
  - `rg -n "authGuard|requirePermission|/api/live/:tenant|/api/webhooks/line|line-content" bn88-backend-v12/src`

## Phase 9+ — Hardening backlog

- Goal: เพิ่มความพร้อม production โดยไม่เปลี่ยน public API
- Scope:
  - เพิ่ม integration tests สำหรับ auth token source / SSE fallback / webhook signature / line-content headers
  - เติม smoke step ของ line-content + webhook dedupe ให้ครบ
  - ลด false-positive จาก IDE/tsserver cache ใน runbook ทีม

