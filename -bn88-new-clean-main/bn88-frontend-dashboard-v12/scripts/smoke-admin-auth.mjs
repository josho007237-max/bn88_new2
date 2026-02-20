#!/usr/bin/env node

const base = process.env.BASE_URL || "http://127.0.0.1:3000";
const tenant = process.env.TENANT || "bn9";
const email = process.env.ADMIN_EMAIL || "root@bn9.local";
const password = process.env.ADMIN_PASSWORD || "bn9@12345";

async function run() {
  const loginRes = await fetch(`${base}/api/admin/auth/login`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-tenant": tenant,
    },
    body: JSON.stringify({ email, password }),
  });

  const loginBody = await loginRes.json().catch(() => ({}));
  if (!loginRes.ok || !loginBody?.token) {
    throw new Error(`login_failed:${loginRes.status}`);
  }

  const authHeaders = {
    Authorization: `Bearer ${loginBody.token}`,
    "x-tenant": tenant,
  };

  const botsRes = await fetch(`${base}/api/admin/bots`, { headers: authHeaders });
  if (botsRes.status !== 200) {
    throw new Error(`bots_expected_200_actual_${botsRes.status}`);
  }

  const lineRes = await fetch(`${base}/api/admin/chat/line-content/FAKE_ID`, {
    headers: authHeaders,
  });

  if (lineRes.status === 401 || lineRes.status === 403) {
    throw new Error(`line_content_auth_error_${lineRes.status}`);
  }

  if (lineRes.status !== 404 && lineRes.status !== 200) {
    throw new Error(`line_content_unexpected_status_${lineRes.status}`);
  }

  console.log(
    JSON.stringify(
      {
        ok: true,
        login: loginRes.status,
        bots: botsRes.status,
        lineContent: lineRes.status,
      },
      null,
      2,
    ),
  );
}

run().catch((err) => {
  console.error(`[smoke-admin-auth] ${err instanceof Error ? err.message : String(err)}`);
  process.exit(1);
});
