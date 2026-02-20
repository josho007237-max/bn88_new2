// src/lib/sse.ts
import type { Request, Response } from "express";
import { sseHub } from "./sseHub";

/** แนบ SSE กับ response (GET /api/events?tenant=xxx) */
export function attachSSE(req: Request, res: Response) {
  const tenant = String(req.query.tenant ?? "").trim();
  if (!tenant) {
    res.status(400).end("tenant required");
    return;
  }

  sseHub.addClient(tenant, res);
}

/** ส่ง event ถึงทุก client ใน tenant นั้นๆ */
export function broadcast(tenant: string, type: string, payload: unknown) {
  sseHub.broadcast({ tenant, type, data: payload } as any);
}

/** ใช้ debug นับจำนวน subscriber ของ tenant */
export function subscribers(tenant: string): number {
  return sseHub.count(tenant);
}
