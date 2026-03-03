import "dotenv/config";

type LoginResponse = {
  ok?: boolean;
  token?: string;
  accessToken?: string;
};

type SessionsResponse = {
  ok?: boolean;
  items?: Array<{ id: string }>;
};

type MessagesResponse = {
  ok?: boolean;
  items?: Array<{ senderType?: string; text?: string }>;
};

const BASE_URL = process.env.BASE_URL || "http://127.0.0.1:3000";
const EMAIL = process.env.SMOKE_EMAIL || "root@bn9.local";
const PASSWORD = process.env.SMOKE_PASSWORD || "bn9@12345";
const TENANT = process.env.SMOKE_TENANT || "bn9";

function assertTrue(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

async function preflightBackend(baseUrl: string): Promise<boolean> {
  try {
    const res = await fetch(`${baseUrl}/api/health`);
    return res.ok;
  } catch {
    return false;
  }
}

async function fetchJson<T>(input: string, init?: RequestInit): Promise<T> {
  const res = await fetch(input, init);
  const text = await res.text();
  const data = text ? JSON.parse(text) : {};
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} ${input} :: ${text}`);
  }
  return data as T;
}

async function main() {
  console.log(`[smoke:p5] baseUrl=${BASE_URL} tenant=${TENANT}`);

  const backendReady = await preflightBackend(BASE_URL);
  if (!backendReady) {
    console.error(
      `Backend not reachable at ${BASE_URL}. Start backend first: npm run dev (PORT 3000) แล้วค่อยรัน smoke:p5`,
    );
    process.exit(1);
  }

  const login = await fetchJson<LoginResponse>(`${BASE_URL}/api/admin/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: EMAIL, password: PASSWORD }),
  });
  const token = login.token || login.accessToken || "";
  assertTrue(Boolean(token), "login token missing");
  console.log("[smoke:p5] login OK");

  const headers = {
    Authorization: `Bearer ${token}`,
    "x-tenant": TENANT,
  };

  const sessions = await fetchJson<SessionsResponse>(
    `${BASE_URL}/api/admin/chat/sessions?limit=5`,
    { headers },
  );
  const items = sessions.items || [];
  assertTrue(items.length > 0, "chat sessions empty");
  const sessionId = items[0]?.id;
  assertTrue(Boolean(sessionId), "sessionId missing");
  console.log(`[smoke:p5] sessions OK count=${items.length} first=${sessionId}`);

  const messages = await fetchJson<MessagesResponse>(
    `${BASE_URL}/api/admin/chat/sessions/${encodeURIComponent(sessionId!)}/messages?limit=20`,
    { headers },
  );
  const hasHello = (messages.items || []).some(
    (m) => m.senderType === "user" && m.text === "hello",
  );
  assertTrue(hasHello, 'missing inbound sample message senderType="user" text="hello"');
  console.log("[smoke:p5] messages OK found user/hello");

  const reply = await fetchJson<{ ok?: boolean; delivered?: boolean }>(
    `${BASE_URL}/api/admin/chat/sessions/${encodeURIComponent(sessionId!)}/reply`,
    {
      method: "POST",
      headers: { ...headers, "Content-Type": "application/json" },
      body: JSON.stringify({ text: "smoke reply" }),
    },
  );
  assertTrue(reply.ok === true, "reply ok != true");
  if (reply.delivered === false) {
    console.log(
      "NOTE: delivered=false is expected for seeded sessions (U_DUMMY). For real delivery, use a real LINE inbound session + set channelAccessToken in BotSecret.",
    );
  }
  console.log("[smoke:p5] reply OK");
  console.log("[smoke:p5] PASS");
}

main().catch((err) => {
  console.error("[smoke:p5] FAIL", err);
  process.exit(1);
});
