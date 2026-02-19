# WORKPLAN STATUS (Phase 0–8)

Scope: `bn88-backend-v12` only, with focus on route mounting, auth/RBAC, bots admin, chat, SSE, LINE webhook, and attachment/media flow.

## Route audit summary (actual mount points in `src/server.ts`)

- Core API: `/api/auth`, `/api/bots`, `/api/cases`, `/api/stats`, `/api/ai/answer`.
- Webhook routes:
  - `/api/webhooks/line` -> `src/routes/webhooks/line.ts`
  - `/api/webhooks/facebook` -> `src/routes/webhooks/facebook.ts`
  - `/api/webhooks/telegram` -> `src/routes/webhooks/telegram.ts`
- Admin routes:
  - Public login: `/api/admin/auth` -> `src/routes/admin/auth.ts`
  - Guarded: `/api/admin/bots`, `/api/admin/chat`, `/api/admin/roles`, `/api/admin/faq`, etc. (all mounted with `authGuard`)

## Auth/RBAC behavior (current)

- `src/mw/auth.ts` is the canonical JWT guard (`authGuard`):
  - Reads token from `Authorization` header, allowed query token paths, or cookie.
  - Sets `req.auth` and compatibility alias `req.admin`.
- `src/middleware/authGuard.ts` now only re-exports from `src/mw/auth.ts`.
- `src/middleware/basicAuth.ts` (`requirePermission`) handles RBAC:
  - Permission by role claim from token.
  - Optional RBAC lookup from DB.
  - Supports superadmin bypass.

### `/api/admin/bots` uses which middleware?

Actual chain:
1. `src/server.ts` mounts `/api/admin/bots` with `authGuard`.
2. `src/routes/admin/bots.ts` additionally applies `requirePermission(["manageBots"])` per endpoint.

So `/api/admin/bots` is guarded by **both** JWT guard (`authGuard`) and RBAC permission guard (`requirePermission`).

## Phase 0–8 status (mapped to requested tracks)

- Phase 0 – Runbook / Local stack: **PARTIAL**
  - Runbook docs exist at repo root, and backend has local scripts.
  - Added PowerShell audit helper for quick local verification.
- Phase 1 – Auth: **DONE (with targeted fix)**
  - Unified guard via `src/mw/auth.ts` + compatibility re-export.
  - Targeted fix applied to reduce false 401/403 in mixed-token scenarios.
- Phase 2 – RBAC: **DONE (with targeted fix)**
  - `requirePermission` checks role mapping + DB RBAC.
  - Added direct permission-claim handling before DB fallback.
- Phase 3 – Bots: **DONE (guard chain verified)**
  - `/api/admin/bots` confirmed mounted and permission-protected.
- Phase 4 – Chat: **DONE (guarded + permission-based)**
  - `/api/admin/chat/*` guarded and permission-gated.
- Phase 5 – SSE: **DONE**
  - `/api/live/:tenant` guarded by `authGuard`; metrics SSE endpoints present.
- Phase 6 – LINE: **DONE**
  - `/api/webhooks/line` mounted with raw-body handling + limiter.
- Phase 7 – Attachments: **DONE**
  - Upload static serving and admin chat line-content route are present.
- Phase 8 – Metrics/Health: **DONE/PARTIAL**
  - Health endpoints and metrics SSE endpoints exist.
  - Deeper metric completeness still depends on operational definitions in master workplan.

## Minimal-diff patch scope

- No API contract changes.
- No route rename.
- No structural refactor.
- Fix is constrained to:
  1. RBAC decision path that can cause `/api/admin/bots` 401/403.
  2. Windows PowerShell audit convenience (`scripts/p0-audit.ps1`).
