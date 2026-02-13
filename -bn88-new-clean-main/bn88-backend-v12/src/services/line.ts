// src/services/line.ts
// ใช้ global fetch ของ Node 18+ / 20+ ได้เลย ไม่ต้องติดตั้ง node-fetch

export type LinePushPayload = {
  channelAccessToken: string; // LINE channel access token ของบอท
  to: string; // userId จาก LINE (เช่น Uxxxxxxxxx)
  text: string; // ข้อความที่ต้องการส่ง
};

/**
 * ส่งข้อความแบบ push ไปหา user ทาง LINE
 * ใช้ตอนแอดมินตอบจากหลังบ้าน (ไม่มี replyToken แล้ว)
 */
export async function sendLinePushMessage({
  channelAccessToken,
  to,
  text,
}: LinePushPayload): Promise<void> {
  const f = (globalThis as any).fetch as typeof fetch | undefined;
  if (!f) {
    console.error("[LINE push] global fetch is not available");
    throw new Error("LINE_FETCH_MISSING");
  }
  if (!text || !text.trim()) {
    console.error("[LINE push] skipped: empty text");
    throw new Error("LINE_PUSH_EMPTY_TEXT");
  }
  const url = "https://api.line.me/v2/bot/message/push";

  const body = {
    to,
    messages: [
      {
        type: "text",
        text,
      },
    ],
  };

  let lastError: any = null;

  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await f(url, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${channelAccessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      });

      const t = await res.text().catch(() => "");

      if (!res.ok) {
        console.error(
          `[LINE push] error attempt ${attempt}: status=${res.status}, body=${t}`,
        );
        throw new Error(`LINE ${res.status}`);
      }

      return;
    } catch (err: any) {
      lastError = err;
      const msg = String(err?.message ?? err);

      console.error(`[LINE push] error attempt ${attempt}:`, msg);

      if (
        attempt < 3 &&
        (/ECONNRESET|ETIMEDOUT|ENETUNREACH|ECONNREFUSED/i.test(msg) ||
          /LINE 5\d\d/.test(msg))
      ) {
        await new Promise((r) => setTimeout(r, 500 * attempt));
        continue;
      }

      break;
    }
  }

  console.error("[LINE push] failed after retries:", lastError);
  throw new Error("LINE_PUSH_FAILED");
}
