# CHECKS REMAINING

## P0 → P1 Checklist (core MVP readiness)
1. **Auth + RBAC ingestion**
   - Acceptance: `authGuard` and `requirePermission` accept the same token regardless of header/cookie/query, login returns JWT/cookie, and `/api/admin/*` calls `200` with `Authorization: Bearer` + `x-tenant`.
   - Command: `pwsh -File bn88-backend-v12/src/scripts/p0-smoke.ps1`
2. **LINE webhook & tunnel readiness**
   - Acceptance: `line.ts` signature verification works when `WEBHOOK_BASE_URL` points to HTTPS tunnel + `BotSecret` exists; `p0-smoke` SSE call succeeded too.
   - Command: `pwsh -File bn88-backend-v12/src/scripts/p0-smoke.ps1`
3. **SSE / ChatCenter connection**
   - Acceptance: `/api/live/:tenant?token=...` keeps streaming via EventSource (no 401), and the smoke script’s SSE step exits 0.
   - Command: see above.
4. **line-content access**
   - Acceptance: `/api/admin/chat/line-content/:id` responds with media when Authorization header (or cookie) is provided; front-end fetch/preview works.
   - Command: (manually download using token) `curl http://localhost:3000/api/admin/chat/line-content/<messageId> -H "Authorization: Bearer <token>" -H "x-tenant: bn9"`
5. **DB audit (1:1 BotConfig/Secret)**
   - Acceptance: No duplicate `botId` rows exist in `BotSecret`/`BotConfig` for the dev SQLite database.
   - Command: `pwsh -File bn88-backend-v12/src/scripts/p0-db-audit.ps1`

## Acceptance criteria per area
- **Auth/RBAC**: login endpoint issues JWT + cookie, `authGuard` uses header/cookie/query, and `requirePermission` sees `req.auth` before rejecting. Invalid or expired tokens return `401 invalid_token` with debug-logging of source.
- **SSE**: EventSource cannot set `Authorization`, so the `token` query param (or `bn88_token` cookie) must be accepted by `/api/live/:tenant`. The smoke script verifies the SSE path.
- **line-content**: The admin route is still protected by RBAC but the dashboard can fetch blob data using `getLineContentBlob` or query-token prefixed URL, so tests should prove the route responds 200 with proper `Content-Type`.
- **DB integrity**: `p0-db-audit.ps1` prints duplicates and exits 1 when duplicates exist; passing run returns zero.
- **Tunnel readiness**: ENV variables `WEBHOOK_BASE_URL`, `LINE_CHANNEL_SECRET`, and `LINE_CHANNEL_ACCESS_TOKEN` must point at an HTTPS tunnel before the webhook signature step is considered reliable (no direct script required, but logged warning indicates misconfiguration).

## Commands (copy/paste)
1. `pwsh -File bn88-backend-v12/src/scripts/p0-smoke.ps1`
2. `pwsh -File bn88-backend-v12/src/scripts/p0-db-audit.ps1`
3. `curl.exe http://localhost:3000/api/admin/auth/login -H 'Content-Type: application/json' -d '{"email":"<ADMIN_EMAIL>","password":"<ADMIN_PASSWORD>"}'`
4. `curl.exe http://localhost:3000/api/admin/bots -H 'Authorization: Bearer <token>' -H 'x-tenant: bn9'`
5. `curl.exe http://localhost:3000/api/admin/chat/sessions?limit=1 -H 'Authorization: Bearer <token>' -H 'x-tenant: bn9'`
6. `curl.exe http://localhost:3000/api/live/bn9?token=<token> -N`
7. `sqlite3 bn88-backend-v12/prisma/dev.db 'SELECT botId, COUNT(*) FROM BotSecret GROUP BY botId HAVING COUNT(*)>1;'`
8. `sqlite3 bn88-backend-v12/prisma/dev.db 'SELECT botId, COUNT(*) FROM BotConfig GROUP BY botId HAVING COUNT(*)>1;'`
9. `rg -n -F 'headers["Authorization"]' bn88-frontend-dashboard-v12\\src -S`
10. `rg -n -F 'req.query.token' bn88-backend-v12\\src -S`
11. `rg -n -F 'Authorization: Bearer' bn88-backend-v12\\src -S`
12. `rg -n -F 'x-tenant' bn88-backend-v12\\src -S`

## Notes on EventSource headers
Browsers cannot attach `Authorization` headers to EventSource requests or `<img>` tags. For development we rely on either a `bn88_token` cookie already set via login or the `token` query parameter that `authGuard` now accepts. When testing the smoke script, the SSE step explicitly adds `?token=...` so the connection can open, and the dashboard should mirror that approach in `getLineContentUrl`.
