// src/live.ts
import type { Request, Response } from "express";
import { sseHub } from "./lib/sseHub";

/**
 * GET /api/live/:tenant
 * เปิดช่องทาง SSE ให้ frontend รับ event แบบ realtime
 */
export function sseHandler(req: Request, res: Response) {
  const tenant = (req.params as any).tenant || "bn9";
  const debugSse = process.env.DEBUG_SSE === "1";

  res.setHeader("Content-Type", "text/event-stream; charset=utf-8");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  (res as any).flushHeaders();
  res.write(":ok\n\n");
  (res as any).flush?.();

  // ✅ ผูก connection นี้เข้ากับ hub ตัวเดียวกับที่ webhook ใช้ broadcast
  const clientId = sseHub.addClient(tenant, res);
  const heartbeat = setInterval(() => {
    res.write(":\n\n");
    (res as any).flush?.();
  }, 15000);

  if (debugSse) {
    console.log("[SSE route] connect", {
      tenant,
      clientId,
      clients: sseHub.count(tenant),
    });
  }

  req.on("close", () => {
    clearInterval(heartbeat);
    sseHub.removeClient(tenant, clientId);

    if (debugSse) {
      console.log("[SSE route] disconnect", {
        tenant,
        clientId,
        clients: sseHub.count(tenant),
      });
    }
  });
}

/**
 * ยิง event ไปให้ทุก client ที่อยู่ tenant เดียวกัน
 * (เผื่อมีโค้ดส่วนอื่นเรียก emit() อยู่ จะไม่พัง)
 */
export function emit(event: string, tenant: string, data: unknown) {
  sseHub.broadcast({
    tenant,
    type: event as any,
    data,
  } as any);
}

