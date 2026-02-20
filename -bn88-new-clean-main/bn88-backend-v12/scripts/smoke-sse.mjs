const baseUrl = process.env.BASE_URL || "http://127.0.0.1:3000";
const email = process.env.ADMIN_EMAIL || "root@bn9.local";
const password = process.env.ADMIN_PASSWORD || "bn9@12345";
const tenant = process.env.TENANT || "bn9";

async function main() {
  const loginResp = await fetch(`${baseUrl}/api/admin/auth/login`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ email, password }),
  });

  if (!loginResp.ok) {
    throw new Error(`login_failed:${loginResp.status}`);
  }

  const loginJson = await loginResp.json();
  const token = String(loginJson?.token || "").trim();
  if (!token) throw new Error("missing_token");

  const sseUrl = `${baseUrl}/api/live/${encodeURIComponent(tenant)}?token=${encodeURIComponent(token)}`;
  const sseResp = await fetch(sseUrl, {
    method: "GET",
    headers: {
      accept: "text/event-stream",
      "x-tenant": tenant,
    },
  });

  if (sseResp.status === 401 || sseResp.status === 403) {
    throw new Error(`sse_auth_failed:${sseResp.status}`);
  }

  if (!sseResp.ok) {
    throw new Error(`sse_http_failed:${sseResp.status}`);
  }

  const contentType = String(sseResp.headers.get("content-type") || "").toLowerCase();
  if (!contentType.includes("text/event-stream")) {
    throw new Error(`sse_invalid_content_type:${contentType || "<empty>"}`);
  }

  sseResp.body?.cancel();

  console.log("[smoke-sse] PASS", {
    status: sseResp.status,
    contentType,
    url: sseUrl,
  });
}

main().catch((err) => {
  console.error("[smoke-sse] FAIL", err?.message || err);
  process.exit(1);
});
