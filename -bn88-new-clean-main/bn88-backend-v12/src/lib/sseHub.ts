// src/lib/sseHub.ts
import type { Response } from "express";
import { randomUUID } from "node:crypto";

type SseClient = {
  id: string;
  tenant: string;
  res: Response;
  heartbeat?: NodeJS.Timeout;
};

type BaseEvent<TType extends string, TData = any> = {
  tenant: string;
  type: TType;
  data?: TData;
  ts?: number;
};

export type EventPayload =
  | BaseEvent<"hello", { clientId: string }>
  | BaseEvent<"ping", { t: number }>
  | BaseEvent<"case:new", any>
  | BaseEvent<"stats:update", any>
  | BaseEvent<"bot:verified", any>
  | BaseEvent<"chat:message:new", any>
  | BaseEvent<string, any>;

class SseHub {
  public readonly __id = randomUUID();

  private clientsByTenant = new Map<string, Map<string, SseClient>>();

  private isDebugEnabled() {
    return process.env.DEBUG_SSE === "1";
  }

  addClient(tenant: string, res: Response) {
    try {
      res.setHeader("Content-Type", "text/event-stream; charset=utf-8");
      res.setHeader("Cache-Control", "no-cache");
      res.setHeader("Connection", "keep-alive");
      res.setHeader("X-Accel-Buffering", "no");
      (res as any).flushHeaders?.();
    } catch {}

    const id = randomUUID();
    const client: SseClient = { id, tenant, res };

    let map = this.clientsByTenant.get(tenant);
    if (!map) {
      map = new Map<string, SseClient>();
      this.clientsByTenant.set(tenant, map);
    }
    map.set(id, client);

    if (this.isDebugEnabled()) {
      console.log("[SSE] addClient", {
        hub: this.__id,
        tenant,
        id,
        clients: map.size,
      });
    }

    this.send(client, {
      tenant,
      type: "hello",
      data: { clientId: id },
      ts: Date.now(),
    });

    client.heartbeat = setInterval(() => {
      try {
        this.write(res as any, `: ping ${Date.now()}\n\n`);
      } catch {}
    }, 15000);

    res.on("close", () => {
      this.removeClient(tenant, id);
    });

    return id;
  }

  removeClient(tenant: string, id: string) {
    const map = this.clientsByTenant.get(tenant);
    const client = map?.get(id);
    if (!map || !client) return;

    try {
      if (client.heartbeat) clearInterval(client.heartbeat);
    } catch {}

    map.delete(id);
    if (map.size === 0) this.clientsByTenant.delete(tenant);

    if (this.isDebugEnabled()) {
      console.log("[SSE] removeClient", {
        hub: this.__id,
        tenant,
        id,
        clients: map.size,
      });
    }
  }

  count(tenant: string) {
    return this.clientsByTenant.get(tenant)?.size ?? 0;
  }

  broadcast(event: EventPayload) {
    const map = this.clientsByTenant.get(event.tenant);
    const n = map?.size ?? 0;

    if (this.isDebugEnabled()) {
      console.log("[SSE] broadcast", {
        hub: this.__id,
        tenant: event.tenant,
        type: event.type,
        clients: n,
      });
    }

    if (!map || n === 0) return;

    const payload: EventPayload = { ...event, ts: event.ts ?? Date.now() };
    for (const client of map.values()) {
      this.send(client, payload);
    }
  }

  emit(type: string, tenant: string, data: unknown) {
    this.broadcast({ tenant, type, data } as EventPayload);
  }

  private send(client: SseClient, event: EventPayload) {
    const resAny = client.res as any;
    if (!resAny || typeof resAny.write !== "function") return;

    const line = `data: ${JSON.stringify(event)}\n\n`;
    this.write(resAny, line);
  }

  private write(resAny: any, text: string) {
    resAny.write(text);
    resAny.flush?.();
  }
}

const g = globalThis as any;
export const sseHub: SseHub =
  g.__BN88_SSE_HUB__ ?? (g.__BN88_SSE_HUB__ = new SseHub());
