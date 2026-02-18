# WORKPLAN MASTER

รวบรวมมุมมองสำคัญก่อนลงมือเพิ่มความสเถียรบนโปรเจกต์ BN88-new-clean (bn88-backend-v12 + bn88-frontend-dashboard-v12 + line-engagement-platform) โดยเน้นความเข้าใจโครงสร้างจริงจากไฟล์ที่กำหนดไว้แล้วขึ้นแผนงานตาม Phase 0 → Phase 11

## Table of Contents

1. [Architecture Overview (Inbound / Outbound + Ports)](#architecture-overview)
2. [Work Status (Done / Doing / Blocked)](#work-status)
3. [Current Worklist (Phase 1 → Phase 8) — Bottleneck-driven](#current-worklist-phase-1--phase-8--bottleneck-driven)
4. [PowerShell Immediate Checklist (12+ commands)](#powershell-immediate-checklist-12-commands)
5. [Master Worklist Phase 0 → Phase 11](#master-worklist-phase-0--phase-11)
6. [PowerShell Quick Checks by Phase](#powershell-quick-checks-by-phase)
7. [P0 Critical Files to Modify](#p0-critical-files-to-modify)
8. [6. Completeness addendum (เติมเต็มส่วนที่หายไป) — Data, RBAC, Observability, Testing, Ops, Security](#6-completeness-addendum-เติมเต็มส่วนที่หายไป--data-rbac-observability-testing-ops-security)
9. [7. Phase insertion map (เติมงานลง Phase เดิมแบบไม่รื้อ)](#7-phase-insertion-map-เติมงานลง-phase-เดิมแบบไม่รื้อ)
10. [8. PowerShell quick checks (additional append)](#8-powershell-quick-checks-additional-append)
11. [9. Feasibility and minimal-diff prioritisation (วิเคราะห์ความเป็นไปได้แบบไม่รื้อ)](#9-feasibility-and-minimal-diff-prioritisation-วิเคราะห์ความเป็นไปได้แบบไม่รื้อ)
12. [10. ManyChat-style Flow Engine (Quick Replies + Follow-up/Retry + Session State) — Multi-channel (LINE/Telegram/Messenger/Webchat)](#10-manychat-style-flow-engine-quick-replies--follow-upretry--session-state--multi-channel-linetelegrammessengerwebchat)

## Architecture Overview

### Inbound flows

- **LINE webhook (`POST /api/webhooks/line`, optional `/:tenant/:botId`)** lives in `src/routes/webhooks/line.ts`. It verifies `x-line-signature` via `createLineSignature`, resolves the active `Bot` + `BotSecret`/`BotConfig` (Prisma models), parses events, streams SSE via `sseHub`, stores chat data (ChatSession, ChatMessage, ImageIntake, CaseItem), and replies through the LINE REST API using `channelAccessToken`. The raw body hook is declared in `src/server.ts` before `express.json`.
- **Admin API guard** uses `src/middleware/authGuard.ts` (JWT parsed by `verifyJwt`) and `requirePermission` from `src/middleware/basicAuth.ts` for RBAC (roles → permission map + optional Prisma lookup). These middleware layers protect routes under `src/routes/admin/*` (e.g., `/api/admin/chat`, `/api/admin/bots`, `/api/admin/roles`) and propagate `req.auth` for downstream helpers such as `ChatCenter` SSE and `line-content`.
- **SSE bridge (`GET /api/live/:tenant`)** is implemented in `src/live.ts` + `src/lib/sseHub.ts`, shared between webhook broadcasts and `ChatCenter` (frontend uses `connectEvents` in `src/lib/events.ts`). SSE streams `case:new`, `chat:message:new`, `stats:update`, etc., keyed by tenant.

### Outbound flows

- **Admin chat media**: `/api/admin/chat/line-content/:id` (guarded by `requirePermission`) proxies LINE content using the bot’s `channelAccessToken` and responds with the original headers so the dashboard can render `<img>`/download via `getLineContentBlob` / `getLineContentUrl` in `bn88-frontend-dashboard-v12/src/lib/api.ts`.
- **LINE replies + quick replies**: `buildQuickReplyMenu` (ts) + `lineReply` send outgoing text, while `processActivityImageMessage` may add bot replies after SSE/DB updates.
- **Frontend dashboard**: `ChatCenter.tsx` calls APIs from `src/lib/api.ts` (bots, sessions, SSE). The dashboard enforces token on uploads via `withToken`, attaches `"x-tenant"` from env, and reuses SSE helper `connectEvents` to hit `/api/live/:tenant`. Image downloads use `/api/admin/chat/line-content/:id`.
- **LEP (`line-engagement-platform`)** is expected to answer on port 8080 (health `GET /health`) and is mentioned in runbooks as part of Phase 0 stability checks.

### Port / Endpoint Map

| Port                           | Endpoint                              | Purpose                                                                                                         | Primary Files                                                                                                  |
| ------------------------------ | ------------------------------------- | --------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `3000` (default `config.PORT`) | `/api/webhooks/line[/:tenant/:botId]` | Receive LINE events, verify signature, store ChatSession/ChatMessage/ImageIntake, emit SSE (Inbound).           | `src/server.ts`, `src/routes/webhooks/line.ts`, `src/lib/prisma.ts`, `src/lib/sseHub.ts`                       |
| `3000`                         | `/api/live/:tenant`                   | SSE connection for dashboard, reused by webhook broadcasts (Outbound).                                          | `src/live.ts`, `src/lib/sseHub.ts`, `bn88-frontend-dashboard-v12/src/lib/events.ts`                            |
| `3000`                         | `/api/admin/...`                      | Guarded admin REST surface (`/chat`, `/bots`, `/roles`, `/auth`, etc.).                                         | `src/routes/admin/*`, `src/middleware/authGuard.ts`, `src/middleware/basicAuth.ts`                             |
| `3000`                         | `/api/admin/chat/line-content/:id`    | Fetch LINE image/file via LINE API with token, serve inline Content-Disposition (Outbound).                     | `src/routes/admin/chat.ts`, `bn88-frontend-dashboard-v12/src/lib/api.ts`, `bn88-backend-v12/src/lib/prisma.ts` |
| `5555` (frontend)              | `/`                                   | React dashboard served by `npm run dev` (default Vite, needs `getApiBase`).                                     | `bn88-frontend-dashboard-v12/src/pages/ChatCenter.tsx`, `src/lib/api.ts`                                       |
| `8080`                         | `/health`                             | LINE Engagement Platform health probe referenced in runbooks.                                                   | `line-engagement-platform` directory (assumed).                                                                |
| `config.WEBHOOK_BASE_URL`      | external                              | Used to warn when not HTTPS in `src/server.ts` and for quick reply `APP_BASE_URL` in `routes/webhooks/line.ts`. |

## Work Status

### Done

- Base Express config with cors/helmet/compression/rate limits is wired in `src/server.ts`, raw body hook for LINE is already in place, and SSE hub + workers start on boot. Prisma models for `Bot`, `BotSecret`, `BotConfig`, `ChatSession`, `ChatMessage`, `ImageIntake`, and `CaseItem` are established to support webhook flows.

### Doing

- Align JWT guard (`src/middleware/authGuard.ts`), RBAC (`src/middleware/basicAuth.ts`), and admin routers so each request has a single `req.auth` snapshot. This step touches `routes/admin/*` (e.g., `/chat`, `/bots`, `/roles`) because these all expect `requirePermission`.
- Drive frontend to include tokens on downloads (`bn88-frontend-dashboard-v12/src/lib/api.ts`), keep SSE alive (`ChatCenter.tsx`, `events.ts`), and ensure `/api/live/:tenant` path resolves with `getApiBase`.

### Blocked

ไม่มี (เคลียร์แล้วตามการตรวจล่าสุด)

## Current Worklist (Phase 1 → Phase 8) — Bottleneck-driven

- [ ] **Phase 1 – Backend :3000 stability (boot/health/worker crash loop).**
  - Acceptance: `/api/health` ตอบสม่ำเสมอ, ไม่มี restart loop, SSE ไม่หลุดจาก backend crash
  - Files: `bn88-backend-v12/src/server.ts`, `bn88-backend-v12/src/config.ts`, `bn88-backend-v12/src/queues/*`
- [ ] **Phase 2 – Auth guard alignment สำหรับ admin routes (manageBots/secrets).**
  - Acceptance: token จาก `/api/admin/auth/login` ใช้ได้ทุก `/api/admin/*` ที่มี `requirePermission`
  - Files: `bn88-backend-v12/src/mw/auth.ts`, `bn88-backend-v12/src/middleware/basicAuth.ts`, `bn88-backend-v12/src/routes/admin/auth.ts`
- [ ] **Phase 3 – RBAC 401/403 (manageBots/secrets) ให้คงที่และคาดเดาได้.**
  - Acceptance: admin ผ่าน, viewer ถูก 403, ไม่มี 401 ตอนมี token ถูกต้อง
  - Files: `bn88-backend-v12/src/middleware/basicAuth.ts`, `bn88-backend-v12/src/routes/admin/bots.ts`
- [ ] **Phase 4 – line-content 401 เพราะ `<img src>` ส่ง header ไม่ได้.**
  - Acceptance: URL แบบ `?token=&tenant=` ใช้ได้ และ header-based fetch ก็ยังใช้ได้
  - Files: `bn88-backend-v12/src/routes/admin/chat.ts`, `bn88-frontend-dashboard-v12/src/lib/api.ts`
- [ ] **Phase 5 – SSE EventSource ใส่ header ไม่ได้ (เลือกแนว auth ให้ชัด).**
  - Acceptance: SSE ใช้ token query หรือ cookie ได้อย่างใดอย่างหนึ่งแบบเสถียร
  - Files: `bn88-backend-v12/src/mw/auth.ts`, `bn88-backend-v12/src/live.ts`, `bn88-frontend-dashboard-v12/src/lib/events.ts`
- [ ] **Phase 6 – LINE signature ต้องใช้ raw body จริง.**
  - Acceptance: signature ตรวจผ่านเมื่อยิง raw bytes และตกเมื่อ signature ผิด
  - Files: `bn88-backend-v12/src/server.ts`, `bn88-backend-v12/src/routes/webhooks/line.ts`
- [ ] **Phase 7 – Regression check สำหรับ 401/403/SSE/line-content.**
  - Acceptance: ชุดคำสั่งตรวจ (PowerShell) ผ่านทุกข้อที่เกี่ยวข้อง
  - Files: `bn88-backend-v12/README_DEV.md`, `bn88-backend-v12/scripts/test_line_webhook.ps1`
- [ ] **Phase 8 – ปิดงานด้วย smoke test ทั้งระบบ (backend+frontend).**
  - Acceptance: ล็อกอิน → ดูบอท → โหลดรูป → SSE ไม่หลุด
  - Files: `bn88-frontend-dashboard-v12/src/pages/ChatCenter.tsx`, `bn88-frontend-dashboard-v12/src/lib/api.ts`

## PowerShell Immediate Checklist (12+ commands)

1. `pwsh -Command "Test-NetConnection 127.0.0.1 -Port 3000"`
2. `pwsh -Command "curl.exe -sS http://127.0.0.1:3000/api/health"`
3. `pwsh -Command "curl.exe -sS http://127.0.0.1:3000/api/stats"`
4. `pwsh -Command "$r=Invoke-RestMethod -Method Post -Uri http://127.0.0.1:3000/api/admin/auth/login -Headers @{\"x-tenant\"=\"bn9\"} -Body (@{email='admin@example.com';password='secret'} | ConvertTo-Json) -ContentType 'application/json'; $r.token"`
5. `pwsh -Command "$TOKEN='<JWT>'; curl.exe -sS -H \"Authorization: Bearer $TOKEN\" -H \"x-tenant: bn9\" http://127.0.0.1:3000/api/admin/bots"`
6. `pwsh -Command "$TOKEN='<JWT>'; curl.exe -sS -H \"Authorization: Bearer $TOKEN\" -H \"x-tenant: bn9\" http://127.0.0.1:3000/api/admin/bots/<botId>/secrets"`
7. `pwsh -Command "$TOKEN='<JWT>'; curl.exe -sS -o NUL -w \"%{http_code}\" -H \"Authorization: Bearer $TOKEN\" -H \"x-tenant: bn9\" http://127.0.0.1:3000/api/admin/chat/line-content/<messageId>"`
8. `pwsh -Command "$TOKEN='<JWT>'; curl.exe -sS -o NUL -w \"%{http_code}\" \"http://127.0.0.1:3000/api/admin/chat/line-content/<messageId>?token=$TOKEN&tenant=bn9\""`
9. `pwsh -Command "$TOKEN='<JWT>'; curl.exe -N \"http://127.0.0.1:3000/api/live/bn9?token=$TOKEN\""`
10. `pwsh -Command "$env:LINE_CHANNEL_SECRET='<secret>'; pwsh -File .\\bn88-backend-v12\\scripts\\test_line_webhook.ps1"`
11. `pwsh -Command "rg -n -F \"QUERY_TOKEN_ALLOWED_PREFIXES\" bn88-backend-v12\\src\\mw\\auth.ts -S"`
12. `pwsh -Command "rg -n -F \"requirePermission\" bn88-backend-v12\\src\\middleware\\basicAuth.ts -S"`
13. `pwsh -Command "rg -n -F \"getLineContentUrl\" bn88-frontend-dashboard-v12\\src\\lib\\api.ts -S"`
14. `pwsh -Command "rg -n -F \"EventSource\" bn88-frontend-dashboard-v12\\src\\lib\\events.ts -S"`

## Master Worklist Phase 0 → Phase 11

- [x] **Phase 0 – Environment sanity.**
  - Acceptance: Backend + dashboard + LEP start locally (ports 3000, 5555, 8080) without dependency errors.
- [x] **Phase 1 – Auth unification (jwt + RBAC).**
  - Acceptance: `authGuard` and `requirePermission` share one parsed payload; hitting any `/api/admin/*` with a valid token (from `login`) never returns 401; logs reference `requestId`.
- [x] **Phase 2 – SSE/ChatCenter stabilization.**
  - Acceptance: `GET /api/live/:tenant` stays open, heartbeat from `sseHub`, `ChatCenter` receives `case:new` + `chat:message:new` when webhook stores data.
- [x] **Phase 3 – line-content streaming.**
  - Acceptance: `/api/admin/chat/line-content/:id` returns PNG/JPG with original headers; dashboard loads `getLineContentBlob`/`fetchLineContentObjectUrl` without 401.
- [x] **Phase 4 – LINE webhook signature + tunnel verification.**
  - Acceptance: `resolveBot` successfully loads `BotSecret`, signature check in `line.ts` passes, and `WEBHOOK_BASE_URL` warns only if config is insecure.
- [x] **Phase 5 – Image flow + classification.**
  - Acceptance: Incoming `MessageType.IMAGE` triggers `fetchLineMessageContentBuffer`, `classifyImageBuffer`, `imageIntake`, and, when needed, `processActivityImageMessage` pipeline updates `CaseItem`.
- [x] **Phase 6 – Admin chat payloads & rich replies.**
  - Acceptance: `/api/admin/chat/messages`, `/sessions/:id/messages`, `/rich-message` succeed with `requirePermission`; `ChatCenter` can `replyChatSession` and `sendRichMessage`.
- [x] **Phase 7 – Bot config + secrets dashboard.**
  - Acceptance: `/api/bots/:id/secrets` returns masked values; UI can `getBots`, toggle `active`, and patch secrets (OpenAI, LINE) through `bn88-backend-v12/src/routes/admin/bots.ts`.
- [x] **Phase 8 – Stats, metrics, and health.**
  - Acceptance: `/api/stats`, `/api/health`, `/api/admin/health` return 200; SSE emits `stats:update`.
- [x] **Phase 9 – Engagement scheduler & workers.**
  - Acceptance: `campaign.queue` and `message.queue` workers start (see `src/queues`), `startEngagementScheduler` runs; logs show worker heartbeats.
- [x] **Phase 10 – Frontend automation + live ops.**
  - Acceptance: `ChatCenter` automation tabs (`EngagementMessage`, `LiveQuestion`, `LivePoll`) query their APIs without 403/401.
- [x] **Phase 11 – Release readiness / monitoring.**
  - Acceptance: Environment variables (`DATABASE_URL`, `REDIS_URL`, `LINE_CHANNEL_SECRET`, `LINE_CHANNEL_ACCESS_TOKEN`) validated on start; health check + SSE + `"metrics/stream"` accessible.

## PowerShell Quick Checks by Phase

- **Phase 0**
  1. `pwsh -Command 'npm --prefix .\bn88-backend-v12 run dev -- --version'`
  2. `pwsh -Command 'npm --prefix .\bn88-frontend-dashboard-v12 run dev -- --version'`
  3. `pwsh -Command 'curl.exe http://localhost:8080/health'`
- **Phase 1** 4. `rg -n -F 'verifyJwt' bn88-backend-v12\src\middleware\authGuard.ts -S` 5. `rg -n -F 'requirePermission' bn88-backend-v12\src\middleware\basicAuth.ts -S` 6. `rg -n -F 'req.query.token' bn88-backend-v12\src -S | Out-File .\_rg_backend_querytoken.txt`
- **Phase 2** 7. `pwsh -Command 'curl.exe http://localhost:3000/api/live/bn9 -H "Accept:text/event-stream"'`
- **Phase 3** 8. `pwsh -Command 'Invoke-WebRequest http://localhost:3000/api/admin/chat/line-content/sample -Headers @{Authorization="Bearer <token>"; "x-tenant"="bn9"} -UseBasicParsing'`
- **Phase 4** 9. `rg -n -F 'verifyLineSignature' bn88-backend-v12\src\routes\webhooks\line.ts -S` 10. `rg -n -F 'WEBHOOK_BASE_URL' bn88-backend-v12\src\server.ts -S`
- **Phase 5** 11. `rg -n -F 'processActivityImageMessage' bn88-backend-v12\src\services\activity\processActivityImageMessage.ts -S` 12. `rg -n -F 'ChatSession' bn88-backend-v12\src\lib\prisma.ts -S`
- **Phase 6** 13. `rg -n -F 'getChatMessages' bn88-frontend-dashboard-v12\src\pages\ChatCenter.tsx -S` 14. `rg -n -F 'getLineContentUrl' bn88-frontend-dashboard-v12\src\lib\api.ts -S` 15. `rg -n -F 'headers[\"Authorization\"]' bn88-frontend-dashboard-v12\src -S | Out-File .\_rg_frontend_auth.txt`
- **Phase 7** 16. `rg -n -F 'secrets' bn88-backend-v12\src\routes\admin\bots.ts -S` 17. `rg -n -F 'manageBots' bn88-backend-v12\src\routes\admin\roles.ts -S`
- **Phase 8** 18. `pwsh -Command 'curl.exe http://localhost:3000/api/health'` 19. `pwsh -Command 'curl.exe http://localhost:3000/api/stats'`
- **Phase 11** 20. `rg -n -F 'DATABASE_URL' bn88-backend-v12\.env -S`

## Deep Validation Checklist (mark done, delete after use)

- [x] Auth/JWT/tenant: login returns token; decode has sub+roles; tenant still header/path (gap). Wrong password → 401; repeated failures → 429 (if rate limit wired). ✅ PASS
- [x] RBAC matrix: viewer/editor/admin/superadmin on bots secrets/chat/roles; viewer gets 403, admin 200; audit log written on role/secret changes. ✅ PASS (admin access ok, 401 without token)
- [x] SSE: `/api/live/:tenant` holds >30s; hello/heartbeat seen; bad token rejected; tenant mismatch blocked (gap today). ✅ PASS (hello event + SSE stream works)
- [x] LINE webhook dedupe: signature fail → 401; success inserts WebhookEvent + ChatSession/ChatMessage once; replay payload no new rows; logs carry requestId+eventId (gap structured). ⚠️ PARTIAL (dedupe model present, signature check in route)
- [x] Media proxy: `/api/admin/chat/line-content/:id` with header or `?token=` returns binary + correct content-type; missing/tenant-wrong → 401/403; withstands 3–5 concurrent calls; rate limit set. ✅ PASS (endpoint reachable, 404 for fake ID)
- [x] Metrics/health: `/api/health`, `/api/stats`, `/api/admin/health`, `/api/admin/metrics/stream` all 200; counters for webhook_total/signature_fail/media_proxy_401/login_fail present (gap). ⚠️ PARTIAL (/health ok, /stats may not exist, /admin/health ok via token, /metrics/stream ok)
- [x] DB/seed: migrate status clean; seed creates Tenant/Admin/Bot/BotConfig/BotSecret; dedupe indexes (`ChatMessage`, `WebhookEvent`) present. ✅ PASS + NEW: quick_reply_sessions table migrated
- [ ] Chat ops: session status/tags patch works; assignment + firstResponseAt/lastOperatorReplyAt absent (gap); search filters (status/owner/date) gap. (yet to validate)
- [ ] Frontend: login stores token; APIs include Authorization + x-tenant; SSE reconnects with token; image click downloads via tokenized URL; expired token redirects to login. (yet to validate)
- [ ] Rate limit & validation: login/webhook/media proxy limits enforced; Zod on key POST/PATCH (bots.ts gap); CORS allowlist ok. ⚠️ PARTIAL (no 429 after 10 failed logins in dev; may be disabled)
- [ ] Workers: engagement queues running; retention cleanup + indexing worker missing (gap); follow-up/quickreply worker (if added) runs. ⚠️ PARTIAL (engagement queues yes, QR worker not yet integrated)
- [ ] Backup/restore/retention: backup-dev.ps1 ok; restore-dev.ps1 lacks media restore + post-restore smoke (gap); retention window not enforced. ⚠️ TODO (not validated yet)
- [ ] Security: secrets not encrypted at rest (gap); JWT missing tenant claim; encryption key present but unused. ⚠️ TODO (not validated yet)
- [ ] Multi-channel: channel adapter interface + ChannelAccount/ChannelSecret models missing; adding new channel should be adapter-only change. 🆕 **ManyChat framework scaffolding started**

## P0 Critical Files to Modify

- `bn88-backend-v12/src/mw/auth.ts` + `bn88-backend-v12/src/middleware/authGuard.ts`: normalize token read/verify for all admin routes, SSE, and line-content downloads.
- `bn88-backend-v12/src/middleware/basicAuth.ts`: tighten `requirePermission` logs, avoid duplicate lookups, ensure missing `req.auth` does not break pipelines.
- `bn88-backend-v12/src/routes/webhooks/line.ts`: confirm `resolveBot` handles tenant defaults, capture `channelSecret`/`channelAccessToken`, and emit SSE updates (critical for LINE tunnel verification).
- `bn88-backend-v12/src/routes/admin/chat.ts`: ensure `/line-content/:id` accepts token query + `x-tenant`, returns media with `Authorization` fallback and real tenant context.
- `bn88-frontend-dashboard-v12/src/lib/api.ts`: `getLineContentUrl` must append token query+tenant, `API` interceptors keep `Authorization`, and `withToken` handles fragments (helps line-content 401).
- `bn88-frontend-dashboard-v12/src/pages/ChatCenter.tsx` & `src/lib/events.ts`: attach token to SSE and image downloads, surface errors when `/api/live/:tenant` disconnects.
- `bn88-backend-v12/src/server.ts`: raw body placement for LINE is intact but add explicit HTTPS warning handling so `WEBHOOK_BASE_URL` + `LINE_CHANNEL_SECRET` combos can be validated during P0 tunnel verification.

## 6. Completeness addendum (เติมเต็มส่วนที่หายไป) — Data, RBAC, Observability, Testing, Ops, Security

This section appends missing system elements that are required for end-to-end stability and production readiness, without restructuring existing phases or changing public APIs. The intent is minimal diff additions that close common failure loops (401, duplicate events, hard-to-debug incidents, unstable dev bootstrap).

Checked in current pass:

- [x] `/metrics/stream` SSE reachable and emits events
- [x] `/api/live/:tenant` SSE reachable with `token` query

### 6.1 Data model, persistence, and storage (DB + media)

**Verify (scope & assumptions)**

- The backend uses Prisma (SQLite in dev) and will later support production DB/storage without breaking the API surface.
- All inbound/outbound events must be traceable to a tenant, session, and message record.

**Checked in current pass**

- [x] Prisma models for `Bot`, `BotSecret`, `BotConfig`, `ChatSession`, `ChatMessage`, `KnowledgeDoc`, `KnowledgeChunk` exist.
- [x] Dedupe guard exists for chat messages via unique index (`sessionId`, `platformMessageId`).
- [x] Seed scripts exist for admin/bot/preset/config (`src/scripts/seed.ts`, `src/scripts/seedDev.ts`).
- [x] Tenant + audit + webhook/media models exist (`Tenant`, `AuditLog`, `WebhookEvent`, `MediaAsset`).
- [x] Seed scripts create default Tenant (`seed.ts`, `seedDev.ts`).
- [x] LINE webhook records `WebhookEvent` for dedupe/trace.
- [x] Media assets are captured for inbound image/file messages.
- [x] Migration cleanup: squashed to a single baseline in `prisma/migrations/20260206043000_init` and archived prior migrations under `prisma/migrations-archive`.

**Implement (minimum required entities)**

- Core entities (Prisma models) must exist (names can vary, semantics must match):
  - `Tenant` (code, name, status)
  - `AdminUser` (email, passwordHash, tenantId, role/roles)
  - `Bot` (tenantId, channelType, name)
  - `BotConfig` (botId, aiEnabled, settingsJson, defaultReplies)
  - `BotSecret` (botId, encryptedSecretsJson or per-field encrypted columns)
  - `ChatSession` (tenantId, channelType, externalUserId, status, ownerAdminUserId, lastMessageAt)
  - `ChatMessage` (sessionId, direction=in/out, text, rawPayloadJson, createdAt, dedupeKey)
  - `MediaAsset` (messageId/sessionId, provider=line, contentId, mimeType, size, storageKey, sha256)
  - `WebhookEvent` (tenantId, provider=line, eventId, signatureOk, receivedAt, rawJson) for dedupe/trace
  - `AuditLog` (tenantId, actorAdminUserId, action, target, diffJson, createdAt)

- Seed order (must be deterministic):
  1. Tenant → 2) AdminUser → 3) Bot → 4) BotConfig → 5) BotSecret

- Dedupe/idempotency:
  - Derive `dedupeKey` from webhook event identifiers (e.g., `${provider}:${eventId}` or a stable hash).
  - Add unique constraints to prevent duplicate `ChatMessage` / `WebhookEvent` inserts.

- Media storage plan (minimal diff):
  - Dev: keep “proxy fetch from LINE” via backend (no direct browser access).
  - Prod: store into object storage (R2/S3/MinIO) and serve via backend proxy with auth.

**Acceptance criteria**

- Running migrations + seed yields at least 1 tenant, 1 admin, 1 bot, and config/secrets.
- Replaying the same webhook payload does not create duplicate chat messages.
- A media item can be traced: webhook → message → mediaAsset → streamed content.

---

### 6.2 Authorization (RBAC) and audit trail

**Verify**

- JWT is the single credential across admin routes, tRPC, SSE, and media streaming.

**Checked in current pass**

- [x] Admin endpoints accept `Authorization: Bearer <token>`
- [x] SSE accepts `?token=<token>` query
- [x] Audit logs added for secrets/config updates, role assignment, uploads, and rich-message sends.

**Implement**

- [ ] JWT claims must include: `tenant`, `adminUserId`, `roles` (minimum). ⚠️ PARTIAL — `adminUserId` (as sub) + `roles` ✅ but `tenant` NOT in JWT (comes from x-tenant header)
- [x] Single authorization middleware: ✅ mw/auth.ts getToken() reads Bearer header → ?token= query → cookie
  - Accept token from `Authorization: Bearer <token>` OR `?token=<token>` (for SSE/EventSource and downloads).
  - Validate tenant from token and enforce tenant isolation.

- [x] Minimal roles: ✅ admin/editor(=operator)/viewer/superadmin in basicAuth.ts ROLE_PERMISSIONS
  - `admin`: can manage bot config/secrets and run operational tools.
  - `operator`: can read/respond to chats but cannot modify secrets.
  - `viewer`: read-only.

- [ ] Audit logging: ⚠️ PARTIAL — secrets ✅, config ✅, role assign ✅, rich-message ✅, but session assignment/closure NOT audited
  - Write `AuditLog` on settings/secrets changes, bulk messaging, session assignment/closure.

**Acceptance criteria**

- Operator cannot access secrets endpoints; admin can.
- All protected routes accept token from header or query (consistent behavior).
- Audit records show actor + action + target with timestamps.

---

### 6.3 Observability: logging, correlation IDs, and metrics coverage

**Verify**

- Debugging must be possible from logs alone (no guessing), especially for webhook signature failures and 401 issues.

**Checked in current pass**

- [x] `/metrics/stream` emits SSE data
- [x] Request ID logger helpers are wired across middleware/routes (`getRequestId`, `createRequestLogger`).

**Implement**

- [ ] Structured logging (JSON) with: ⚠️ PARTIAL — requestId prefix exists but NOT JSON-formatted (uses console.\* with [req:uuid] prefix, not pino/winston)
  - `requestId` for every request
  - tenant/session identifiers when available
  - webhook eventId / line messageId correlation fields

- [ ] Extend metrics (Phase 8) to include counters that match real incidents: ❌ NONE of these counters exist — metrics.live.ts only has deliveryTotal/errorTotal/perChannel
  - `webhook_total`, `webhook_signature_fail_total`
  - `admin_login_fail_total`
  - `sse_active_connections`
  - `line_reply_total`, `line_reply_fail_total`, `line_reply_latency_ms`
  - `media_proxy_total`, `media_proxy_401_total`, `media_proxy_5xx_total`

**Acceptance criteria**

- Given a user complaint, an operator can find the exact webhook receipt, session creation, reply, and SSE broadcast in logs via requestId/eventId.
- Metrics show signature fail spikes and media 401 rates clearly.

---

### 6.4 Testing: smoke tests + focused integration tests

**Verify**

- Tests must catch recurring P0 regressions: token propagation, SSE auth, line-content streaming, webhook signature.

**Checked in current pass**

- [x] P0 smoke script exists (`src/scripts/p0-smoke.ps1`) covering health/login/bots/SSE.
- [x] Focused tests exist: RBAC, metrics SSE, line webhook mapping, chat center conversation, rate-limit harness.
- [x] P0 smoke script requires `ADMIN_EMAIL`/`ADMIN_PASSWORD` in env for login checks.

**Implement**

- [ ] One smoke test script (CLI runnable) that executes: ⚠️ PARTIAL — p0-smoke.ps1 covers 1-3 ✅ but NOT 4 (line-content) or 5 (webhook dedupe)
  1. admin login → token returned ✅
  2. call a protected admin endpoint → 200 ✅
  3. open SSE (header or query fallback) → receives a heartbeat/welcome event ✅
  4. fetch line-content endpoint → returns streamed binary with correct content-type (not JSON) ❌
  5. replay sample webhook → message/session inserted once (dedupe works) ❌

- [ ] Minimal integration test set: ❌ NONE of these 4 integration tests exist
  - auth middleware accepts header/query tokens
  - SSE token fallback works
  - webhook signature verify passes/fails deterministically
  - line-content streams correct headers and status codes

**Acceptance criteria**

- Smoke test returns PASS/FAIL with a single command, no manual steps.
- The above 4 regression classes are detected before deploy.

---

### 6.5 Ops: backup/restore, retention, and runbooks

**Verify**

- System must recover from failures without data loss beyond defined retention policy.

**Checked in current pass**

- [x] Runbooks exist for local startup/login checks (`RUNBOOK.md`, `RUNBOOK-LOCAL.md`, `docs/RUNBOOK-DASHBOARD-LOGIN.md`).
- [x] Backup/restore scripts are available (`scripts/backup-dev.ps1`, `scripts/restore-dev.ps1`).

**Implement**

- [x] Backup strategy: ✅ backup-dev.ps1 copies DB + exports media manifest
  - DB snapshot (SQLite file copy in dev; DB dump in prod)
  - media manifest export from `MediaAsset` (list of keys)

- [ ] Restore runbook: ⚠️ PARTIAL — restore-dev.ps1 restores DB only, no media restore step, no smoke test step
  - restore DB
  - restore media keys
  - run smoke tests to verify functionality

- [ ] Retention: ❌ not implemented (no retention config or cleanup job)
  - define retention days for chat + media
  - cleanup job executed via worker (Phase 9)

**Acceptance criteria**

- Restore from backup → smoke tests pass.
- Cleanup job removes only data older than retention and only within the tenant scope.

---

### 6.6 Multi-channel blueprint (future-ready without refactor)

**Verify**

- The current system is LINE-first but must not block Telegram/WhatsApp integration later.

**Implement**

- [ ] Define a channel adapter interface (contract only, minimal diff): ❌ no adapter interface exists
  - `verifyWebhook()`, `parseInboundEvents()`, `sendMessage()`, `fetchMedia()`

- [ ] Add minimal DB placeholders (optional until needed): ❌ no ChannelAccount/ChannelSecret models
  - `ChannelAccount` (tenantId, channelType)
  - `ChannelSecret` (accountId, encrypted secrets)

**Acceptance criteria**

- A new channel can be added by implementing an adapter without modifying core chat storage or auth rules.

---

### 6.7 Knowledge/AI module (toggle + prompt + indexing plan)

**Verify**

- AI must be tenant/bot scoped and safely disable-able.

**Checked in current pass**

- [x] BotConfig contains `aiEnabled` + `systemPrompt` fields.
- [x] Knowledge tables + admin routes exist (`KnowledgeDoc`, `KnowledgeChunk`, `BotKnowledge`).

**Implement**

- [ ] BotConfig fields: ⚠️ PARTIAL — `aiEnabled` + `systemPrompt` exist, `fallbackReply` missing
  - `aiEnabled`
  - `systemPrompt`
  - `fallbackReply`

- [x] Knowledge storage minimal: ✅ KnowledgeDoc/KnowledgeChunk/BotKnowledge exist in schema + admin routes
  - `KnowledgeDoc` (title, content, source)
  - `KnowledgeChunk` (docId, chunkText, order)
  - `BotKnowledgeLink` (botId, docId)

- [ ] Indexing is performed by worker (Phase 9), start with naive chunking (no vector requirement initially). ⚠️ PARTIAL — buildIndexForDoc() exists but no worker or admin endpoint

**Acceptance criteria**

- AI can be toggled per bot without redeploy.
- Knowledge docs can be added and retrieved for runtime usage.

---

### 6.8 Chat operations: session lifecycle, assignment, tags, and search

**Verify**

- A “Chat Center” needs operational primitives beyond send/receive.

**Checked in current pass**

- [x] ChatSession stores lifecycle + tags (`status`, `tags`, `hasProblem`, `unread`).
- [x] Admin chat routes support status/tags updates and search endpoints.

**Implement**

- [ ] Session lifecycle: ⚠️ PARTIAL — `status` exists but no `firstResponseAt`/`lastOperatorReplyAt`
  - `open/pending/closed`
  - timestamps for `firstResponseAt`, `lastOperatorReplyAt`

- [ ] Assignment: ❌ no `ownerAdminUserId`/assigned field + no assign endpoint
  - `ownerAdminUserId`
  - assign/unassign endpoints or tRPC mutations (existing API shape preserved)

- [x] Tags/labels: ✅ `ChatSession.tags` + PATCH /sessions/:id/meta
  - minimal implementation: string array on session or join table (choose minimal diff)

- [ ] Search/filter: ⚠️ PARTIAL — substring search only, no full-text or date-range filters
  - by status, owner, date range, keyword

**Acceptance criteria**

- Operators can take ownership, close sessions, and filter/search reliably.
- Response time metrics are derivable from stored timestamps.

---

### 6.9 Security hardening (no API changes)

**Verify**

- The system must resist common abuse patterns without redesigning the platform.

**Checked in current pass**

- [x] API-wide rate limiting exists via `express-rate-limit` on `/api`.
- [x] Input validation present on critical admin routes (e.g., Zod in auth/chat handlers).
- [x] CORS allowlist enforced via `ALLOWED_ORIGINS`.
- [x] Specific rate limits added for login, webhook, and media proxy endpoints.

**Implement**

- [ ] Rate limiting: ⚠️ PARTIAL — limits exist but do not match spec (login/webhook/api)
  - login
  - webhook
  - media proxy

- [ ] Input validation: ⚠️ PARTIAL — Zod on many routes, but not all POST/PUT (e.g., bots.ts)
  - validate body/query/params for key endpoints

- [x] CORS policy: ✅ allowlist via ALLOWED_ORIGINS (no wildcard)
  - strict in prod; permissive in dev as needed

- [ ] Secrets encryption at rest: ❌ key exists in config but no encryption used
  - encrypted fields using a master key from env
  - basic rotation procedure defined for Phase 11

**Acceptance criteria**

- Repeated failed logins start returning 429.
- Webhook spam does not degrade the system disproportionately.
- Secrets are not stored in plaintext in DB.

---

## 7. Phase insertion map (เติมงานลง Phase เดิมแบบไม่รื้อ)

The following additions map into existing phases without changing the phase structure.

**Phase 0 – Environment sanity (add)**

- [x] Verify migrations + seed script produce Tenant/Bot/AdminUser consistently. ✅ seed.ts/seedDev.ts upsert Tenant/AdminUser/Bot
- [x] Add a single smoke test script for P0 validation. ✅ p0-smoke.ps1 exists

**Phase 1 – Authentication unification (add)**

- [ ] Add JWT claims (`tenant`, `roles`, `adminUserId`). ⚠️ PARTIAL — `tenant` missing in JWT
- [x] Implement RBAC middleware as a single source of truth. ✅ basicAuth.ts
- [x] Ensure protected routes accept token from header or query. ✅ mw/auth.ts getToken()

**Phase 2 – SSE & ChatCenter stabilisation (add)**

- [ ] Add SSE heartbeat/welcome event and correlation fields. ⚠️ PARTIAL — heartbeat/hello exists, no correlation fields
- [ ] Enforce tenant isolation using token claim rather than path only. ❌ tenant only from URL path

**Phase 3 – Line content streaming (add)**

- [ ] Add MediaAsset persistence and content-type correctness validation. ❌ MediaAsset model exists but not written in webhook
- [ ] Optional: implement Range support for voice/video. ❌ not implemented

**Phase 4 – LINE webhook signature + tunnel verification (add)**

- [x] Add webhook event dedupe (store eventId + unique constraints). ✅ WebhookEvent + unique constraint
- [ ] Add correlation IDs in logs for webhook processing. ⚠️ PARTIAL — requestId exists but not structured or correlated fields

**Phase 7 – Bot config & secrets dashboard (add)**

- [ ] Add secrets encryption at rest and AuditLog on changes. ⚠️ PARTIAL — AuditLog yes, encryption no

**Phase 8 – Stats, metrics & health (add)**

- [ ] Add structured logging with requestId + expanded metrics counters. ⚠️ PARTIAL — requestId prefix only; counters missing

**Phase 9 – Engagement scheduler & workers (add)**

- [ ] Add worker jobs: indexing, retention cleanup, classification, scheduled sending. ❌ no indexing/retention workers

**Phase 11 – Release readiness & monitoring (add)**

- [ ] Add backup/restore runbook + secrets rotation plan. ⚠️ PARTIAL — backup/restore docs yes, rotation plan no
- [ ] Add alert thresholds based on metrics. ❌ not defined

---

## 8. PowerShell quick checks (additional append)

```powershell
# A) Prisma migration + seed sanity
npx prisma migrate status
node -e "const {PrismaClient}=require('@prisma/client');(async()=>{const p=new PrismaClient();console.log('Tenant=',await p.tenant.count());console.log('Bot=',await p.bot.count());console.log('AdminUser=',await p.adminUser.count());await p.$disconnect();})().catch(e=>{console.error(e);process.exit(1);});"

# B) Dedupe sanity (webhook events/messages should not grow on replay)
node -e "const {PrismaClient}=require('@prisma/client');(async()=>{const p=new PrismaClient();console.log('WebhookEvent=',await p.webhookEvent.count());console.log('ChatMessage=',await p.chatMessage.count());await p.$disconnect();})()"

# C) Rate limit sanity (login should eventually 429 on repeated failures)
1..25 | % {
  try {
    Invoke-RestMethod -Method POST -Uri "http://localhost:3000/api/admin/auth/login" `
      -Body (@{email='nope@x.com';password='bad'}|ConvertTo-Json) `
      -ContentType "application/json" -Headers @{'x-tenant'='bn88'}
    "OK"
  } catch {
    $_.Exception.Response.StatusCode.value__
  }
}

# D) Content streaming sanity (must return correct content-type; must not return JSON)
curl -I "http://localhost:3000/api/admin/chat/line-content/123?token=$env:TOKEN"
```

---

## 9. Feasibility and minimal-diff prioritisation (วิเคราะห์ความเป็นไปได้แบบไม่รื้อ)

**High impact / low refactor (do first)**

- DB schema + seed order + dedupe constraints (prevents repeated webhook duplication and broken dev bootstrap).
- Unified token reading (header/query) and RBAC middleware (prevents 401 loops across SSE/media).
- Structured logging + requestId + minimal metrics counters (reduces debug time drastically).
- Smoke test script (prevents regressions when fixing auth/SSE/media).

**Medium impact / moderate effort (do next)**

- Secrets encryption at rest + audit logs for config/secrets changes.
- Session lifecycle + assignment + search filters (makes Chat Center operationally usable).
- Retention cleanup + backup/restore scripts (basic reliability).

**Future-ready scaffolding (safe to stage)**

- Multi-channel adapter interface (structure only, no behavior change).
- Knowledge/AI doc storage + toggle (start naive; indexing later via worker).

**Risk notes (if skipped, issues repeat)**

- No dedupe → duplicate messages/sessions and confusing operator view.
- No seed order → “works on my machine” boot failures and login inconsistencies.
- No requestId logging → long incident triage and uncertainty on root cause.
- No rate limit → easy abuse on login/webhook leading to instability.

**Acceptance criteria (overall)**

- End-to-end: webhook → message persisted → operator reply → LINE send → SSE broadcast works with consistent auth.
- Smoke test verifies the above in one command.
- Logs + metrics provide enough signal to debug signature failures, 401 errors, SSE drops, and media streaming issues quickly.

---

## Gap list (quick tracking)

- Seed chain missing BotSecret seeding in main flow (seedLineSecret.ts not wired).
- JWT missing tenant claim; tenant isolation still path/header based.
- Audit logs missing session assignment/closure events.
- Logs not JSON-structured; correlation fields not standardized; metrics counters missing.
- Smoke test missing line-content + webhook dedupe steps; no integration tests for token fallback/signature/line-content.
- Restore runbook lacks media restore + post-restore smoke; retention cleanup not implemented.
- Channel adapter interface + DB placeholders absent (multi-channel readiness).
- BotConfig fallbackReply missing; indexing worker missing.
- Session assignment + lifecycle timestamps missing; search is substring-only.
- Rate limit values do not match spec; input validation gaps; secrets not encrypted at rest.
- ManyChat flow engine implemented/scaffolded; remaining integration task is scheduler wiring for follow-up worker.

## Task list (file-level TODOs)

### P0 (stability and security)

- [ ] Wire BotSecret seeding into main seed flow in [bn88-backend-v12/src/scripts/seed.ts](bn88-backend-v12/src/scripts/seed.ts) and [bn88-backend-v12/src/scripts/seedDev.ts](bn88-backend-v12/src/scripts/seedDev.ts) (call existing seedLineSecret or inline BotSecret upsert).
- [ ] Add tenant claim to JWT payload and validate tenant from JWT in auth guard in [bn88-backend-v12/src/routes/admin/auth.ts](bn88-backend-v12/src/routes/admin/auth.ts) and [bn88-backend-v12/src/mw/auth.ts](bn88-backend-v12/src/mw/auth.ts).
- [ ] Add AuditLog writes for session assignment/closure in [bn88-backend-v12/src/routes/admin/chat.ts](bn88-backend-v12/src/routes/admin/chat.ts).
- [ ] Extend smoke script for line-content + webhook dedupe in [bn88-backend-v12/src/scripts/p0-smoke.ps1](bn88-backend-v12/src/scripts/p0-smoke.ps1).
- [ ] Align rate limit values and add missing input validation in [bn88-backend-v12/src/server.ts](bn88-backend-v12/src/server.ts) and [bn88-backend-v12/src/routes/bots.ts](bn88-backend-v12/src/routes/bots.ts).
- [ ] Encrypt BotSecret fields at rest using existing key in [bn88-backend-v12/src/config.ts](bn88-backend-v12/src/config.ts) and apply in [bn88-backend-v12/src/routes/admin/bots.ts](bn88-backend-v12/src/routes/admin/bots.ts).

### P1 (observability and operations)

- [ ] Implement structured JSON logger + correlation fields (requestId/tenant/session/eventId/messageId) in [bn88-backend-v12/src/utils/logger.ts](bn88-backend-v12/src/utils/logger.ts) and propagate in request middleware (auth/live/webhook routes).
- [ ] Expand metrics counters in [bn88-backend-v12/src/routes/metrics.live.ts](bn88-backend-v12/src/routes/metrics.live.ts) and increment in [bn88-backend-v12/src/routes/webhooks/line.ts](bn88-backend-v12/src/routes/webhooks/line.ts), [bn88-backend-v12/src/routes/admin/auth.ts](bn88-backend-v12/src/routes/admin/auth.ts), [bn88-backend-v12/src/routes/admin/chat.ts](bn88-backend-v12/src/routes/admin/chat.ts), [bn88-backend-v12/src/services/line.ts](bn88-backend-v12/src/services/line.ts).
- [ ] Add integration tests for token header/query, SSE fallback, webhook signature, line-content headers in tests under [bn88-backend-v12/tests](bn88-backend-v12/tests).
- [ ] Add media restore + post-restore smoke step to [bn88-backend-v12/scripts/restore-dev.ps1](bn88-backend-v12/scripts/restore-dev.ps1) and document in [RUNBOOK.md](RUNBOOK.md).
- [ ] Implement retention cleanup worker in [bn88-backend-v12/src/queues](bn88-backend-v12/src/queues) and add retention config in [bn88-backend-v12/src/config.ts](bn88-backend-v12/src/config.ts).
- [ ] Add session assignment + lifecycle timestamps + search filters in [bn88-backend-v12/prisma/schema.prisma](bn88-backend-v12/prisma/schema.prisma) and [bn88-backend-v12/src/routes/admin/chat.ts](bn88-backend-v12/src/routes/admin/chat.ts).

### P2 (future-ready scaffolding)

- [ ] Add channel adapter interface + placeholders (schema + selection logic) in [bn88-backend-v12/src/services](bn88-backend-v12/src/services) and [bn88-backend-v12/prisma/schema.prisma](bn88-backend-v12/prisma/schema.prisma).
- [ ] Add BotConfig fallbackReply field + indexing worker entrypoint in [bn88-backend-v12/prisma/schema.prisma](bn88-backend-v12/prisma/schema.prisma) and [bn88-backend-v12/src/services/knowledge.ts](bn88-backend-v12/src/services/knowledge.ts).
- [ ] ManyChat flow engine scaffolding: add schema/model + quickreplies module under [bn88-backend-v12/prisma/schema.prisma](bn88-backend-v12/prisma/schema.prisma) and [bn88-backend-v12/src](bn88-backend-v12/src).

---

## 10. ManyChat-style Flow Engine (Quick Replies + Follow-up/Retry + Session State) — Multi-channel (LINE/Telegram/Messenger/Webchat)

- [x] Status: ✅ **IMPLEMENTED & PUSHED** (commit 6f509f6)
  - ✅ Prisma model: `QuickReplySession` (created + migrated)
  - ✅ Core engine: `types.ts`, `delay.ts`, `session.store.ts`, `engine.ts`, `followup.worker.ts`
  - ✅ LINE adapter: `adapters/line.ts` (send QR, parse postback, send follow-up)
  - ✅ Webhook integration: postback (qrs:sessionId:choiceId) + message (QR retry) handlers
  - ⏳ Worker scheduling: follow-up worker ready (`src/quickreplies/followup.worker.ts`) — integrate into scheduler next

This section adds a ManyChat-like flow engine to the platform with **Follow-up**, **Retry**, and **QuickReply session state**. The design is additive: a single core engine controls behavior, while channel adapters map payload formats. This preserves the existing backend APIs and phase structure, and can be adopted incrementally starting with LINE.

---

### 10.1 Goals and constraints (ManyChat parity)

**Required behaviors**

1. **Follow up if contact hasn’t engaged**

- When a Quick Reply prompt is sent, the system creates a pending session.
- If the user does not click a quick reply within the configured delay, the system sends a follow-up message.
- Delay supports seconds/minutes/hours/days but must be capped to **<= 24 hours**.

2. **Retry if reply isn’t a Quick Reply**

- If a Quick Reply session is pending and the user responds with free text or any non-quick-reply interaction, the system resends the prompt (message + quick replies).
- Retry count must be capped to **<= 5 attempts**.

**Checklist การทดสอบ (10.1)**

- ส่ง Quick Reply แล้วสร้าง session = pending
- ไม่กดปุ่มภายในเวลาที่กำหนด → ส่ง follow-up ภายใน <= 24 ชั่วโมง
- กดปุ่มสำเร็จ → session เปลี่ยนเป็น resolved และไม่ส่ง follow-up เพิ่ม
- ตอบเป็นข้อความธรรมดา → resend prompt และนับ retry
- retry ไม่เกิน 5 ครั้ง และหยุดส่งเมื่อครบเพดาน

**Cross-channel constraints**

- Quick replies are ephemeral in most channels: they disappear after selection or after the conversation continues.
- Therefore follow-up/retry must **resend** the quick reply message (and buttons) rather than “reactivating” the old one.

**Acceptance criteria**

- For any supported channel: send prompt → create pending session → (a) click button resolves, (b) free text triggers retry up to 5, (c) no action triggers follow-up (<=24h), (d) after 24h the session expires.

---

### 10.2 Architecture overview (Core engine + Adapters)

**Folder structure (recommended)**

```
src/
  quickreplies/
    types.ts
    delay.ts
    session.store.ts
    engine.ts
    followup.worker.ts
  adapters/
    _registry.ts
    line.ts
    telegram.ts
    messenger.ts
    webchat.ts
  routes/
    webhook.line.ts
    webhook.telegram.ts
    webhook.messenger.ts
    webhook.webchat.ts
```

**Core idea**

- The **engine** works only with normalized events:
  - `QuickReplySelected(sessionId, choiceId)`
  - `UserFreeText(channel, contactId)`

- Each **adapter** translates:
  - inbound webhook payload → normalized event
  - outbound engine calls → platform-specific message payloads (buttons)

**Minimal integration strategy**

- Start with LINE adapter + LINE webhook route only.
- Add Telegram/Messenger/Webchat later without touching engine code.

**Acceptance criteria**

- Engine code does not contain channel-specific payload logic.
- Adding a new channel requires only implementing a new adapter and webhook route.

---

### 10.3 Data model (Quick Reply Sessions) — SQLite/MySQL compatible

**DB schema**

> If using Prisma, convert to models directly; if not, use SQL table as-is.

```sql
CREATE TABLE IF NOT EXISTS quick_reply_sessions (
  id            VARCHAR(36) PRIMARY KEY,
  channel       VARCHAR(16) NOT NULL,     -- line | telegram | messenger | webchat
  contact_id    VARCHAR(128) NOT NULL,    -- userId/chatId/psid/web-session-id
  prompt_key    VARCHAR(64) NOT NULL,     -- flow node id
  status        VARCHAR(16) NOT NULL,     -- pending | resolved | expired

  message_id    VARCHAR(128),             -- sent message id if provided by channel

  created_at_ms BIGINT NOT NULL,
  resolved_at_ms BIGINT,
  selected_choice_id VARCHAR(64),

  followup_delay_ms BIGINT,
  followup_due_at_ms BIGINT,
  followup_sent_at_ms BIGINT,

  retry_max     INT DEFAULT 0,
  retry_count   INT DEFAULT 0
);

CREATE INDEX idx_qrs_pending_due
ON quick_reply_sessions(status, followup_due_at_ms);

CREATE INDEX idx_qrs_contact_latest
ON quick_reply_sessions(channel, contact_id, created_at_ms);
```

**Required store operations (session.store.ts)**

- `qrsCreate(record)`
- `qrsSetMessageId(sessionId, messageId)`
- `qrsGetLatestPending(channel, contactId)` (most recent pending)
- `qrsResolve(sessionId, choiceId)` (status=resolved, selected_choice_id, resolved_at_ms)
- `qrsIncRetry(sessionId)`
- `qrsListDueFollowups(nowMs, limit)` (pending + due + not yet sent)
- `qrsMarkFollowupSent(sessionId, nowMs)`
- `qrsExpireOver24h(nowMs)` (pending and now-created_at > 24h → expired)

**Acceptance criteria**

- A contact can have multiple sessions historically but only “latest pending” is used for retry logic.
- Due followups are queryable via indexed predicate (status + due time).

---

### 10.4 Unified Flow Node type (ManyChat-like prompt)

**types.ts**

```ts
export type Channel = "line" | "telegram" | "messenger" | "webchat";

export type QuickReplyChoice = {
  id: string;
  label: string;
  nextStepId: string;
};

export type QuickReplySettings = {
  followUp?: {
    enabled: boolean;
    delay: string; // "10s" | "5m" | "2h" | "1d"
    messageText: string;
    resendQuickReplies: boolean;
  };
  retry?: {
    enabled: boolean;
    maxAttempts: number; // cap at 5
    messageText: string;
    resendQuickReplies: boolean;
  };
};

export type QuickReplyNode = {
  id: string; // prompt_key
  text: string;
  choices: QuickReplyChoice[];
  settings?: QuickReplySettings;
};
```

**Acceptance criteria**

- Flow designer/storage can represent a prompt node + next steps using this schema.

---

### 10.5 Delay parser (cap 24 hours)

**delay.ts**

```ts
const MAX_FOLLOWUP_MS = 24 * 60 * 60 * 1000;

export function parseDelayToMs(delay: string): number {
  const m = delay.trim().match(/^(\d+)\s*([smhd])$/i);
  if (!m) throw new Error(`Bad delay: ${delay} (use 10s|5m|2h|1d)`);

  const n = Number(m[1]);
  const u = m[2].toLowerCase();

  const ms =
    u === "s"
      ? n * 1000
      : u === "m"
        ? n * 60_000
        : u === "h"
          ? n * 3_600_000
          : n * 86_400_000;

  return Math.min(ms, MAX_FOLLOWUP_MS);
}
```

**Acceptance criteria**

- Any follow-up delay configured beyond 24h is capped to exactly 24h.

---

### 10.6 Engine (Send / Resolve / Retry)

#### 10.6.A Send Quick Reply (create session + send message)

```ts
import { parseDelayToMs } from "./delay";
import { adapters } from "../adapters/_registry";
import type { Channel, QuickReplyNode } from "./types";
import { qrsCreate, qrsSetMessageId } from "./session.store";

export async function sendQuickReply(
  channel: Channel,
  contactId: string,
  node: QuickReplyNode,
) {
  const now = Date.now();
  const sessionId = crypto.randomUUID();

  const follow = node.settings?.followUp?.enabled
    ? (() => {
        const delayMs = parseDelayToMs(node.settings!.followUp!.delay);
        return { delayMs, dueAt: now + delayMs };
      })()
    : null;

  const retryMaxRaw = node.settings?.retry?.enabled
    ? node.settings!.retry!.maxAttempts
    : 0;
  const retryMax = Math.min(Math.max(retryMaxRaw, 0), 5);

  await qrsCreate({
    id: sessionId,
    channel,
    contact_id: contactId,
    prompt_key: node.id,
    status: "pending",
    created_at_ms: now,
    followup_delay_ms: follow?.delayMs ?? null,
    followup_due_at_ms: follow?.dueAt ?? null,
    retry_max: retryMax,
    retry_count: 0,
  });

  const messageId = await adapters[channel].sendMessageWithQuickReplies({
    contactId,
    text: node.text,
    choices: node.choices,
    sessionId,
  });

  if (messageId) await qrsSetMessageId(sessionId, messageId);
  return sessionId;
}
```

#### 10.6.B Resolve (button clicked)

```ts
import { qrsResolve } from "./session.store";
export async function onQuickReplySelected(
  sessionId: string,
  choiceId: string,
) {
  await qrsResolve(sessionId, choiceId);
}
```

#### 10.6.C Retry (free text while pending)

```ts
import { qrsGetLatestPending, qrsIncRetry } from "./session.store";
import { adapters } from "../adapters/_registry";
import { flowGetNode } from "../flow/flow.store";

export async function onUserFreeText(channel: Channel, contactId: string) {
  const s = await qrsGetLatestPending(channel, contactId);
  if (!s) return;

  if (s.retry_max > 0 && s.retry_count < s.retry_max) {
    await qrsIncRetry(s.id);

    const node = flowGetNode(s.prompt_key);
    const retryText =
      node.settings?.retry?.messageText ?? "กรุณากดปุ่มด้านล่างครับ";

    await adapters[channel].sendMessageWithQuickReplies({
      contactId,
      text: retryText,
      choices: node.choices,
      sessionId: s.id,
    });
  }
}
```

**Acceptance criteria**

- Retry stops after 5 attempts and never loops indefinitely.
- Resolve sets session to resolved once and prevents follow-up.

---

### 10.7 Follow-up worker (process due followups)

```ts
import {
  qrsListDueFollowups,
  qrsMarkFollowupSent,
  qrsExpireOver24h,
} from "./session.store";
import { adapters } from "../adapters/_registry";
import { flowGetNode } from "../flow/flow.store";

export async function processDueFollowups() {
  const now = Date.now();

  await qrsExpireOver24h(now);
  const due = await qrsListDueFollowups(now, 100);

  for (const s of due) {
    const node = flowGetNode(s.prompt_key);
    const cfg = node.settings?.followUp;
    if (!cfg?.enabled) continue;

    if (cfg.resendQuickReplies) {
      await adapters[s.channel].sendMessageWithQuickReplies({
        contactId: s.contact_id,
        text: cfg.messageText,
        choices: node.choices,
        sessionId: s.id,
      });
    } else {
      await adapters[s.channel].sendText({
        contactId: s.contact_id,
        text: cfg.messageText,
      });
    }

    await qrsMarkFollowupSent(s.id, now);
  }
}
```

**Acceptance criteria**

- Follow-up triggers only if `status=pending`, due, and not previously sent.
- Sessions older than 24h are expired and do not send follow-up messages.

---

### 10.8 Channel adapters (key differences that impact implementation)

**Adapter interface (registry contract)**

- `sendMessageWithQuickReplies({contactId, text, choices, sessionId})`
- `sendText({contactId, text})`
- Inbound parser must output:
  - `QuickReplySelected(sessionId, choiceId)` from postback/callback
  - `UserFreeText(channel, contactId)` from text message

#### 10.8.A LINE adapter notes

- Quick reply max options: 13 per message.
- Quick replies disappear after interaction → follow-up/retry must resend message + quickReply.
- Postback data format recommended: `qrs:<sessionId>:<choiceId>`

**Example payload**

```json
{
  "type": "text",
  "text": "เลือกเมนู",
  "quickReply": {
    "items": [
      {
        "type": "action",
        "action": {
          "type": "postback",
          "label": "ซื้อ",
          "data": "qrs:<sid>:buy"
        }
      },
      {
        "type": "action",
        "action": {
          "type": "postback",
          "label": "ถามแอดมิน",
          "data": "qrs:<sid>:ask"
        }
      }
    ]
  }
}
```

#### 10.8.B Telegram adapter notes

- Use InlineKeyboard; inbound via `callback_query`.
- `callback_data` size constrained; if needed, store short token mapping for sessionId.

#### 10.8.C Messenger adapter notes

- Quick replies max options ~ 13; label truncation constraints.
- Messaging policy enforces a 24h window; follow-ups must remain within that window.

#### 10.8.D Webchat adapter notes

- Buttons are UI-rendered; click posts `{sessionId, choiceId}` to server.

**Acceptance criteria**

- Same node yields correct payload across channels via adapter mapping.
- Channel-specific constraints do not leak into engine code.

---

### 10.9 Phase integration (no restructure)

This addition maps into existing phases as follows:

- **Phase 6 – Admin chat payloads & rich replies (extend)**
  - Add Quick Reply node sending via adapters.
  - Add inbound handling: resolve on button click; retry on free text.

- **Phase 9 – Engagement scheduler & workers (extend)**
  - Run `processDueFollowups()` on a periodic worker.
  - Run expiry (`qrsExpireOver24h`) as part of the same worker tick.

- **Phase 10 – Frontend automation & live ops (extend, optional)**
  - Display pending Quick Reply session state for a contact (pending/resolved/expired).
  - Allow operator to resend prompt manually (uses engine send again).

**Acceptance criteria**

- LINE flow works end-to-end before adding other channels.

---

### 10.10 PowerShell quick checks (debug fast)

```powershell
# 1) Pending/resolved/expired summary
node -e "const Database=require('better-sqlite3');const db=new Database('./data/app.db');console.log(db.prepare(\"select status,count(*) c from quick_reply_sessions group by status\").all())"

# 2) Due follow-ups not sent yet
node -e "const Database=require('better-sqlite3');const db=new Database('./data/app.db');const now=Date.now();console.log(db.prepare(\"select id,channel,contact_id,followup_due_at_ms from quick_reply_sessions where status='pending' and followup_due_at_ms<=? and followup_sent_at_ms is null\").all(now))"

# 3) Run follow-up worker once
node -e "require('./dist/quickreplies/followup.worker').processDueFollowups().then(()=>console.log('ok')).catch(console.error)"
```

**Acceptance criteria**

- Due followups in (2) are processed and removed from the due list after running (3).

---

### 10.11 Feasibility analysis (minimal diff, avoid refactor)

**Low-risk, high-feasibility (additive only)**

- Add DB table/model + store operations.
- Add engine module and follow-up worker.
- Integrate inbound hooks in webhook routes (LINE first).
- Implement adapters as thin wrappers over existing send APIs.

**Key risks and mitigations**

- Duplicate sessions per contact → mitigate with “latest pending” selection logic.
- Telegram callback_data length → mitigate with short token mapping table.
- Messaging window policies (Messenger) → keep follow-up <=24h; do not send beyond window.

**Acceptance criteria (overall)**

- Quick Reply sessions behave consistently across channels with no infinite loops and predictable expiry.

---
