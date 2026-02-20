// src/routes/live.ts
import { Router } from "express";
import { sseHub } from "../lib/sseHub";

export const live = Router();

live.get("/live/:tenant", (req, res) => {
  const { tenant } = req.params;

  res.setHeader("Content-Type", "text/event-stream; charset=utf-8");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  (res as any).flushHeaders?.();
  res.write(":ok\n\n");

  const clientId = sseHub.addClient(tenant, res);

  const heartbeat = setInterval(() => {
    res.write(":\n\n");
    (res as any).flush?.();
  }, 15000);

  req.on("close", () => {
    clearInterval(heartbeat);
    sseHub.removeClient(tenant, clientId);
    res.end();
  });
});
