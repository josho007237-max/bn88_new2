const baseUrl = process.env.BASE_URL || "http://127.0.0.1:3000";
const email = process.env.ADMIN_EMAIL || "root@bn9.local";
const password = process.env.ADMIN_PASSWORD || "bn9@12345";
const tenant = process.env.TENANT || "bn9";
const lineContentId = (process.env.LINE_CONTENT_ID || "").trim();

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

  const lineHeaderResp = await fetch(`${baseUrl}/api/admin/chat/line-content/FAKE_ID`, {
    headers: {
      authorization: `Bearer ${token}`,
      "x-tenant": tenant,
    },
  });
  if (lineHeaderResp.status === 401 || lineHeaderResp.status === 403) {
    throw new Error(`line_content_fake_header_auth_failed:${lineHeaderResp.status}`);
  }
  if (lineHeaderResp.status !== 404) {
    throw new Error(`line_content_fake_header_expected_404:${lineHeaderResp.status}`);
  }

  const lineQueryResp = await fetch(
    `${baseUrl}/api/admin/chat/line-content/FAKE_ID?token=${encodeURIComponent(token)}&tenant=${encodeURIComponent(tenant)}`
  );
  if (lineQueryResp.status === 401 || lineQueryResp.status === 403) {
    throw new Error(`line_content_fake_query_auth_failed:${lineQueryResp.status}`);
  }
  if (lineQueryResp.status !== 404) {
    throw new Error(`line_content_fake_query_expected_404:${lineQueryResp.status}`);
  }

  if (lineContentId) {
    const lineRealResp = await fetch(`${baseUrl}/api/admin/chat/line-content/${encodeURIComponent(lineContentId)}`, {
      headers: {
        authorization: `Bearer ${token}`,
        "x-tenant": tenant,
      },
    });

    if (lineRealResp.status === 401 || lineRealResp.status === 403) {
      throw new Error(`line_content_real_auth_failed:${lineRealResp.status}`);
    }
    if (!lineRealResp.ok) {
      throw new Error(`line_content_real_http_failed:${lineRealResp.status}`);
    }

    const lineRealType = String(lineRealResp.headers.get("content-type") || "").toLowerCase();
    if (!(lineRealType.startsWith("image/") || lineRealType.includes("application/octet-stream"))) {
      throw new Error(`line_content_real_invalid_content_type:${lineRealType || "<empty>"}`);
    }

    lineRealResp.body?.cancel();
  }

  console.log("[smoke-sse] PASS", {
    sse: { status: sseResp.status, contentType, url: sseUrl },
    lineContentFakeHeaderStatus: lineHeaderResp.status,
    lineContentFakeQueryStatus: lineQueryResp.status,
    lineContentRealChecked: Boolean(lineContentId),
  });
}

main().catch((err) => {
  console.error("[smoke-sse] FAIL", err?.message || err);
  process.exit(1);
});
