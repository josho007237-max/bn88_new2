# BN88 Reset Book (One Pager)

> เป้าหมาย: เปิดมาแล้ว “ไม่หลง” ภายในหน้าเดียว, เน้นแก้ให้จบไวแบบ **minimal diff**, **ไม่เปลี่ยน API**, **ไม่รื้อโครงสร้างใหญ่**

## 1) Monorepo map (ต้องรู้ก่อนเริ่ม)

- `bn88-backend-v12` = Backend API + webhook + admin routes + SSE
- `bn88-frontend-dashboard-v12` = Admin Dashboard (Vite/React)
- `line-engagement-platform` = LEP service แยกโดเมนงาน engagement

## 2) Architecture (เส้นทางหลักที่ต้องนึกภาพให้ออก)

1. **LINE inbound**
   - LINE ส่ง event เข้า `POST /api/webhooks/line` (หรือ route tenant/bot)
   - Backend verify signature ด้วย `LINE_CHANNEL_SECRET`
   - บันทึกลง DB (`ChatSession`, `ChatMessage`)
   - broadcast ไป SSE ให้ Dashboard อัปเดต

2. **Admin outbound**
   - Admin reply ผ่าน `/api/admin/chat/...`
   - Backend ใช้ token ของ bot ส่งออกไป LINE
   - media path ใช้ `/api/admin/chat/line-content/:id`

3. **SSE realtime**
   - Dashboard subscribe `GET /api/live/:tenant`
   - เมื่อ webhook/admin action เกิด event จะ push ผ่าน SSE

4. **Admin API security**
   - Route กลุ่ม `/api/admin/*` ใช้ JWT (`Authorization: Bearer <token>`)
   - แนบ `x-tenant` เสมอ (default tenant ที่ใช้คือ `bn9`)

## 3) Ports / Env ที่จำเป็นต้องล็อกให้ตรง

- Ports หลัก: backend `3000`, dashboard `5555`, redis(host) `6380`
- Frontend env: `VITE_API_BASE` (ควรชี้ backend `/api`)
- LINE env: `LINE_CHANNEL_SECRET`, `LINE_CHANNEL_ACCESS_TOKEN`
- Tenant มาตรฐานที่ใช้ทดสอบ: `tenant=bn9`

## 4) Current blockers checklist (เช็คเรียงตามนี้ก่อน)

- [ ] **(1) CWD/path ผิด** ทำให้ `npm`/`rg` fail
  - อาการ: `No such file or directory`, script หาไฟล์ไม่เจอ
  - แก้: `cd /workspace/bn88_new2/-bn88-new-clean-main` แล้วค่อยสั่งงานใน package เป้าหมาย

- [ ] **(2) `api.ts` มีปัญหา `getLineContentPath` ซ้ำ/หาย**
  - อาการ: TS2393 duplicate function implementation หรือหา helper ไม่เจอ
  - เงื่อนไขที่ถูกต้อง: มี `getLineContentPath(id: string)` แค่หนึ่งจุด และ
    - `getLineContentUrl()` ใช้ helper นี้
    - `getLineContentBlob()` ใช้ helper นี้
    - path ต้องเป็น `/admin/chat/line-content/:id` + `encodeURIComponent`

- [ ] **(3) Cloudflare 1033** เพราะ tunnel/ingress ไม่ชี้ backend `:3000`
  - อาการ: health ผ่าน local แต่โดเมน tunnel ใช้ไม่ได้
  - แก้: ตรวจ tunnel config/ingress ให้ forward ไป `http://127.0.0.1:3000`

## 5) Master Worklist (Phase 0–9+)

> แต่ละเฟสมี acceptance + คำสั่งทดสอบแบบสั้นเพื่อเดินงานต่อได้ทันที

### Phase 0 — Bootstrap/CWD sanity
- Acceptance:
  - อยู่ root monorepo ถูกที่
  - เข้าแต่ละ package แล้ว `npm -v`/`node -v` ได้
- Commands:
  - `pwd`
  - `test -f README.md && echo OK`
  - `cd bn88-backend-v12 && npm run -s env >/dev/null 2>&1 || true`

### Phase 1 — Backend up (`:3000`)
- Acceptance:
  - `GET /api/health` ตอบ 200
- Commands:
  - `cd bn88-backend-v12 && npm run dev`
  - `curl -sS http://127.0.0.1:3000/api/health`

### Phase 2 — Dashboard up (`:5555`) + API base
- Acceptance:
  - Dashboard เปิดได้
  - `VITE_API_BASE` ชี้ backend ถูก
- Commands:
  - `cd bn88-frontend-dashboard-v12 && npm run dev`
  - `rg -n "VITE_API_BASE" .env .env.local 2>/dev/null`

### Phase 3 — Auth + tenant guard
- Acceptance:
  - login ได้ token
  - เรียก `/api/admin/*` ด้วย JWT + `x-tenant: bn9` ได้
- Commands:
  - `curl -sS -X POST http://127.0.0.1:3000/api/admin/auth/login -H 'Content-Type: application/json' -H 'x-tenant: bn9' -d '{"email":"admin@example.com","password":"secret"}'`
  - `curl -sS http://127.0.0.1:3000/api/admin/bots -H 'Authorization: Bearer <TOKEN>' -H 'x-tenant: bn9'`

### Phase 4 — DB chat flow integrity
- Acceptance:
  - มีข้อมูล `ChatSession`/`ChatMessage` ผูกกันถูก
- Commands:
  - `cd bn88-backend-v12 && npx prisma studio` (ตรวจด้วยตา)
  - หรือยิง endpoint sessions/messages ใน admin chat

### Phase 5 — SSE realtime
- Acceptance:
  - ต่อ `GET /api/live/bn9` ได้ และมี event ไหลเมื่อมีข้อความเข้า/ตอบกลับ
- Commands:
  - `curl -N "http://127.0.0.1:3000/api/live/bn9?token=<TOKEN>"`

### Phase 6 — LINE media path integrity (`line-content`)
- Acceptance:
  - helper เดียวใน frontend
  - download/open media ผ่าน `/api/admin/chat/line-content/:id` ได้
- Commands:
  - `cd /workspace/bn88_new2/-bn88-new-clean-main`
  - `rg -n "function getLineContentPath" bn88-frontend-dashboard-v12/src/lib/api.ts`
  - `curl -sS -o /dev/null -w "%{http_code}\n" "http://127.0.0.1:3000/api/admin/chat/line-content/<messageId>" -H 'Authorization: Bearer <TOKEN>' -H 'x-tenant: bn9'`

### Phase 7 — Type safety + lint safety
- Acceptance:
  - frontend typecheck ผ่าน
  - lint ผ่าน
- Commands:
  - `cd bn88-frontend-dashboard-v12 && npx tsc -p tsconfig.json --noEmit`
  - `cd bn88-frontend-dashboard-v12 && npm run lint`

### Phase 8 — Tunnel/webhook domain readiness
- Acceptance:
  - tunnel health ผ่าน, ไม่เจอ 1033
  - LINE webhook URL ชี้โดเมน HTTPS ที่ยิงเข้า backend `:3000`
- Commands:
  - `curl -sS https://<tunnel-domain>/api/health`
  - `cloudflared tunnel --protocol http2 --url http://127.0.0.1:3000`

### Phase 9+ — Hardening/ops (ไม่รื้อ)
- Acceptance:
  - มี smoke checklist รันซ้ำได้
  - deploy แล้ว flow เดิมไม่พัง
- Commands:
  - `./smoke.ps1` (Windows) หรือคำสั่ง curl ชุดเดียวกันตาม RUNBOOK
  - `rg -n "webhooks/line|/api/live|line-content" bn88-backend-v12/src bn88-frontend-dashboard-v12/src`

## 6) Fast verify snippet (กันหลงซ้ำ)

- Linux/macOS:
  - `rg -n "function getLineContentPath" bn88-frontend-dashboard-v12/src/lib/api.ts`
- PowerShell (ถ้ามี):
  - `Select-String -Path "bn88-frontend-dashboard-v12/src/lib/api.ts" -Pattern "function getLineContentPath" -Context 2,2`

---

## Golden rules (ห้ามลืม)

- **ห้ามเปลี่ยน API contract**
- **ห้ามรื้อโครงสร้างใหญ่**
- **เน้น minimal diff + ตรวจซ้ำตาม phase ก่อนขยับงานถัดไป**
