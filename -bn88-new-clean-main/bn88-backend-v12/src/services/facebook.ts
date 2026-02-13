// src/services/facebook.ts
import { config } from "../config";

export async function sendFacebookMessage(
  pageAccessToken: string,
  psid: string,
  text: string,
): Promise<boolean> {
  const f = (globalThis as any).fetch as typeof fetch | undefined;
  if (!f) {
    console.error("[FACEBOOK] global fetch is not available");
    return false;
  }
  if (!pageAccessToken) {
    console.warn("[FACEBOOK] Missing pageAccessToken");
    return false;
  }
  if (!psid) {
    console.warn("[FACEBOOK] Missing psid");
    return false;
  }
  if (!text || !text.trim()) {
    console.warn("[FACEBOOK] sendMessage skipped: empty text");
    return false;
  }

  const url = `https://graph.facebook.com/v18.0/me/messages?access_token=${encodeURIComponent(
    pageAccessToken,
  )}`;

  const body = {
    messaging_type: "RESPONSE",
    recipient: { id: psid },
    message: { text },
  };

  let lastError: any = null;

  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const resp = await f(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });

      const raw = await resp.text().catch(() => "");

      if (!resp.ok) {
        console.warn(
          `[FACEBOOK sendMessage error attempt ${attempt}: status=${resp.status}, body=${raw}]`,
        );
        throw new Error(`FACEBOOK ${resp.status}`);
      }

      const data = raw ? (JSON.parse(raw) as any) : null;
      if (!data || !data.recipient_id) {
        console.warn("[FACEBOOK sendMessage bad response]", data);
        return false;
      }

      return true;
    } catch (err: any) {
      lastError = err;
      const msg = String(err?.message ?? err);

      console.warn(`[FACEBOOK sendMessage error attempt ${attempt}:`, msg);

      if (
        attempt < 3 &&
        (/ECONNRESET|ETIMEDOUT|ENETUNREACH|ECONNREFUSED/i.test(msg) ||
          /FACEBOOK 5\d\d/.test(msg))
      ) {
        await new Promise((r) => setTimeout(r, 500 * attempt));
        continue;
      }

      break;
    }
  }

  console.warn("[FACEBOOK sendMessage failed after retries]", lastError);
  return false;
}
