// src/scripts/seedLineSecret.ts
const BASE_URL = (process.env.API_BASE_URL || "http://127.0.0.1:3000").replace(
  /\/+$/,
  ""
);
const TENANT = process.env.TENANT || "bn9";
const BOT_ID = process.env.BOT_ID || "dev-bot";

const channelSecret = process.env.LINE_CHANNEL_SECRET || "";
const accessToken =
  process.env.LINE_CHANNEL_ACCESS_TOKEN || process.env.LINE_ACCESS_TOKEN || "";

if (!channelSecret || !accessToken) {
  console.error(
    "[seed-line-secret] missing env: LINE_CHANNEL_SECRET and LINE_CHANNEL_ACCESS_TOKEN are required"
  );
  process.exit(1);
}

async function main() {
  const url = `${BASE_URL}/api/bots/${BOT_ID}/secrets`;
  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-tenant": TENANT,
    },
    body: JSON.stringify({
      lineAccessToken: accessToken,
      lineChannelSecret: channelSecret,
    }),
  });

  const text = await resp.text().catch(() => "");
  if (!resp.ok) {
    console.error("[seed-line-secret] failed", resp.status, text);
    process.exit(1);
  }
  console.log("[seed-line-secret] ok", text || resp.status);
}

main().catch((err) => {
  console.error("[seed-line-secret] error", err);
  process.exit(1);
});
