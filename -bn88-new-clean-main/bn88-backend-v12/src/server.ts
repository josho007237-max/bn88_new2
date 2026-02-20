// src/server.ts
process.on("unhandledRejection", (err) =>
  console.error("[UNHANDLED REJECTION]", err),
);
process.on("uncaughtException", (err) =>
  console.error("[UNCAUGHT EXCEPTION]", err),
);

import * as fs from "node:fs";
import * as path from "node:path";
import dotenv from "dotenv";
const envCandidates = [
  path.resolve(process.cwd(), ".env"),
  path.resolve(process.cwd(), "bn88-backend-v12/.env"),
];
const envPath = envCandidates.find((p) => fs.existsSync(p));
dotenv.config(envPath ? { path: envPath } : undefined);

function detectDuplicateEnvKeys(filePath: string) {
  try {
    const raw = fs.readFileSync(filePath, "utf8");
    const lines = raw.split(/\r?\n/);
    const lineMap = new Map<string, number[]>();
    const keyPattern = /^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=/;
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const match = line.match(keyPattern);
      if (!match?.[1]) continue;
      const key = match[1];
      const prev = lineMap.get(key) ?? [];
      prev.push(i + 1);
      lineMap.set(key, prev);
    }

    for (const [key, rows] of lineMap.entries()) {
      if (rows.length <= 1) continue;
      console.error(
        `[BOOT][ENV_DUPLICATE] key "${key}" appears ${rows.length} times in ${filePath} (lines: ${rows.join(", ")})`,
      );
    }
  } catch (err) {
    console.warn("[BOOT][ENV_CHECK_WARN] cannot read env file", filePath, err);
  }
}

if (envPath) {
  detectDuplicateEnvKeys(envPath);
} else {
  console.warn("[BOOT][ENV_WARN] .env file not found from cwd");
}

import express, {
  type Request,
  type Response,
  type NextFunction,
} from "express";
import cors from "cors";
import morgan from "morgan";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import compression from "compression";
import { ZodError } from "zod";
import cookieParser from "cookie-parser";

import { config } from "./config";
import { logger } from "./mw/logger";
import { authGuard } from "./mw/auth";
import { sseHandler } from "./live";
import { metricsSseHandler, metricsStreamHandler } from "./routes/metrics.live";
import { prisma } from "./lib/prisma";
import { runDevPreflight } from "./lib/devPreflight";

import { startEngagementScheduler } from "./services/engagementScheduler";
import { startCampaignScheduleWorker } from "./queues/campaign.queue";
import { startMessageWorker } from "./queues/message.queue";

/* Core routes */
import health from "./routes/health";
import authRoutes from "./routes/auth";
import casesRoutes from "./routes/cases";
import statsRoutes from "./routes/stats";
import botsRoutes from "./routes/bots";
import botsSummary from "./routes/bots.summary";
import devRoutes from "./routes/dev";
import lineTools from "./routes/tools/line";
import aiAnswerRoute from "./routes/ai/answer";
import events from "./routes/events";

/* Webhooks */
import lineWebhookRouter from "./routes/webhooks/line";
import telegramWebhookRouter from "./routes/webhooks/telegram";
import facebookWebhookRouter from "./routes/webhooks/facebook";

/* Admin */
import adminAuthRoutes from "./routes/admin/auth";
import adminBotsRouter from "./routes/admin/bots";
import adminBotIntentsRouter from "./routes/admin/botIntents";
import adminRouter from "./routes/admin";
import presetsAdmin from "./routes/admin/ai/presets";
import knowledgeAdmin from "./routes/admin/ai/knowledge";
import adminPersonaRoutes from "./routes/admin/personas";
import { chatAdminRouter } from "./routes/admin/chat";
import lepAdminRouter from "./routes/admin/lep";
import { telegramLiveAdminRouter } from "./routes/admin/telegramLive";
import adminRolesRouter from "./routes/admin/roles";
import botAutomationRouter from "./routes/admin/botAutomation";
import adminFaqRouter from "./routes/admin/faq";
import adminUploadsRouter from "./routes/admin/uploads";

const app = express();
app.set("trust proxy", 1);

const webhookBaseUrl = (process.env.WEBHOOK_BASE_URL || "").trim();
if (webhookBaseUrl) {
  const lower = webhookBaseUrl.toLowerCase();
  const isHttp = lower.startsWith("http://");
  const isLocal =
    lower.includes("localhost") ||
    lower.includes("127.0.0.1") ||
    lower.includes("0.0.0.0");
  if (isHttp || isLocal) {
    console.warn(
      `[WARN] LINE webhook requires HTTPS. WEBHOOK_BASE_URL=${webhookBaseUrl} is not public HTTPS. ` +
        "Use a tunnel (cloudflared tunnel --url http://localhost:3000).",
    );
  }
}

/* Workers */
void runDevPreflight()
  .then((result) => {
    if (!result.prismaWritable) {
      console.warn("[BOOT] prisma directory is not writable; check DATABASE_URL path/permissions");
    }

    if (result.redisEnabled && !result.redisReachable) {
      console.warn("[BOOT] Redis unavailable; queue workers are disabled in this run");
      return;
    }

    try {
      startCampaignScheduleWorker();
    } catch (err) {
      console.error("[BOOT] campaign worker start failed", err);
    }
    try {
      startMessageWorker();
    } catch (err) {
      console.error("[BOOT] message worker start failed", err);
    }
  })
  .catch((err) => {
    console.warn("[BOOT] preflight failed; continuing with queue workers disabled", err);
  });

/* simple probes */
app.get("/", (_req, res) => res.send("ok"));
app.get("/health", (_req, res) => res.redirect("/api/health"));

/* ✅ Serve uploads (ครั้งเดียวพอ) */
app.use("/uploads", express.static(path.join(process.cwd(), "uploads")));
app.use("/api/uploads", express.static(path.join(process.cwd(), "uploads")));

/* ---------- Body parsers ---------- */
/* parsers ทั่วไป + เก็บ raw bytes เฉพาะ LINE webhook (Ticket 04) */
app.use(
  "/api/webhooks/line",
  express.raw({ type: "*/*", limit: "1mb" }),
  (req, _res, next) => {
    if (Buffer.isBuffer(req.body)) {
      (req as any).rawBody = req.body;
    }
    return next();
  },
);
app.use(
  express.json({
    limit: "1mb",
    verify: (req: any, _res, buf) => {
      if (req.originalUrl && req.originalUrl.startsWith("/api/webhooks/line")) {
        req.rawBody = buf;
      }
    },
  }),
);
app.use((req, res, next) => {
  if (req.path.startsWith("/api/webhooks/line")) return next();
  return express.urlencoded({ extended: false, limit: "200kb" })(
    req,
    res,
    next,
  );
});
app.use(cookieParser());

app.use((err: any, _req: Request, res: Response, next: NextFunction) => {
  if (err?.type === "entity.too.large") {
    return res.status(413).json({ ok: false, message: "payload_too_large" });
  }
  if (err?.type === "entity.parse.failed") {
    return res.status(400).json({ ok: false, message: "invalid_json" });
  }
  return next(err);
});

/* Security / CORS / Log */
const allowList = new Set(
  (config.ALLOWED_ORIGINS || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean),
);

const localOriginPattern = /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i;
const defaultAllowedOrigins = new Set(["https://admin.bn9.app"]);

const corsOptions: cors.CorsOptions = {
  origin: (origin, cb) => {
    if (!origin) return cb(null, true);
    if (localOriginPattern.test(origin)) return cb(null, true);
    if (defaultAllowedOrigins.has(origin)) return cb(null, true);
    if (allowList.has(origin)) return cb(null, true);
    return cb(null, false);
  },
  credentials: true,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization", "x-tenant", "x-admin-key"],
};

app.use(
  helmet({
    contentSecurityPolicy: false,
    crossOriginResourcePolicy: { policy: "cross-origin" },
  }),
);

app.use(cors(corsOptions));
app.options("*", cors(corsOptions));

app.use(morgan("dev"));
app.use(logger);

/* Compression (skip SSE) */
app.use(
  compression({
    filter: (req, res) => {
      const accept = String(req.headers.accept || "");
      if (accept.includes("text/event-stream")) return false;
      if (req.path.startsWith("/api/live/")) return false;
      return compression.filter(req, res as any);
    },
  }),
);

/* Rate limit (mounted on /api) */
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) =>
    req.path.startsWith("/webhooks/") ||
    req.path === "/health" ||
    req.path.startsWith("/live/") ||
    req.path.startsWith("/events") ||
    req.path.startsWith("/admin/chat"),
});
app.use("/api", limiter);

const webhookLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 120,
  standardHeaders: true,
  legacyHeaders: false,
  message: { ok: false, message: "rate_limited" },
});

/* Health */
app.use("/api/health", health);
app.get("/api/health", (_req, res) =>
  res.json({
    ok: true,
    time: new Date().toISOString(),
    adminApi: true,
  }),
);

/* Dev & tools */
app.use("/api", devRoutes);
app.use("/api", lineTools);
app.use("/api", events);

/* Core */
app.use("/api/auth", authRoutes);
app.use("/api/bots", botsRoutes);
app.use("/api/bots", botsSummary);
app.use("/api/cases", casesRoutes);

app.get("/api/stats", async (req: Request, res: Response) => {
  try {
    const tenant =
      (req.headers["x-tenant"] as string) ||
      process.env.TENANT_DEFAULT ||
      "bn9";
    const sinceDaysRaw = Number(req.query?.sinceDays ?? 7);
    const sinceDays = Number.isFinite(sinceDaysRaw)
      ? Math.min(Math.max(Math.round(sinceDaysRaw), 1), 365)
      : 7;

    const toUTC = new Date();
    const fromUTC = new Date(toUTC.getTime() - sinceDays * 24 * 60 * 60 * 1000);

    const [messages, cases, bots] = await Promise.all([
      prisma.chatMessage.count({
        where: { tenant, createdAt: { gte: fromUTC, lte: toUTC } },
      }),
      prisma.caseItem.count({
        where: { tenant, createdAt: { gte: fromUTC, lte: toUTC } },
      }),
      prisma.bot.count({ where: { tenant } }),
    ]);

    return res.json({
      ok: true,
      tenant,
      window: {
        sinceDays,
        fromUTC: fromUTC.toISOString(),
        toUTC: toUTC.toISOString(),
      },
      totals: { messages, cases, bots },
    });
  } catch (err) {
    console.error("[/api/stats] fallback error", err);
    return res.status(500).json({ ok: false, message: "internal_error" });
  }
});

app.use("/api/stats", statsRoutes);
app.use("/api/ai/answer", aiAnswerRoute);

/* Realtime */
app.get("/api/live/:tenant", authGuard, sseHandler);
app.get("/api/live/metrics", metricsSseHandler);
app.get("/metrics/stream", metricsStreamHandler);

try {
  startEngagementScheduler().catch((err) =>
    console.error("[BOOT] engagement scheduler error", err),
  );
} catch (err) {
  console.error("[BOOT] engagement scheduler crashed", err);
}

/* Webhooks */
app.use("/api/webhooks/line", webhookLimiter, lineWebhookRouter);
app.use("/api/webhooks/facebook", webhookLimiter, facebookWebhookRouter);
app.use("/api/webhooks/telegram", webhookLimiter, telegramWebhookRouter);

/* Admin */
app.use("/api/admin/uploads", adminUploadsRouter);

if (config.ENABLE_ADMIN_API === "1") {
  console.log("[BOOT] Admin API enabled (guarded by JWT)");

  // ✅ public
  app.use("/api/admin/auth", adminAuthRoutes);

  // ✅ guarded
  app.use("/api/admin/faq", authGuard, adminFaqRouter);
  app.use("/api/admin/bots", authGuard, adminBotsRouter);
  app.use("/api/admin/bots", authGuard, adminBotIntentsRouter);
  app.use("/api/admin/chat", authGuard, chatAdminRouter);
  app.use("/api/admin/chats", authGuard, chatAdminRouter);
  app.use("/api/admin/lep", authGuard, lepAdminRouter);
  app.use("/api/admin/telegram", authGuard, telegramLiveAdminRouter);
  app.use("/api/admin/roles", authGuard, adminRolesRouter);
  app.use("/api/admin/bot", authGuard, botAutomationRouter);

  app.use("/api/admin/ai/presets", authGuard, presetsAdmin);
  app.use("/api/admin/ai/knowledge", authGuard, knowledgeAdmin);
  app.use("/api/admin/ai/personas", authGuard, adminPersonaRoutes);

  // ✅ mount adminRouter ครั้งเดียว
  app.use("/api/admin", authGuard, adminRouter);
}

/* 404 & Errors */
app.use("/api", (_req: Request, res: Response) => {
  res.status(404).json({ ok: false, message: "not_found" });
});

app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
  if (err instanceof ZodError) {
    return res
      .status(400)
      .json({ ok: false, message: "invalid_input", issues: err.issues });
  }
  if (err?.type === "entity.parse.failed" || err instanceof SyntaxError) {
    return res.status(400).json({ ok: false, message: "invalid_json" });
  }
  console.error("[INTERNAL ERROR]", err);
  return res.status(500).json({ ok: false, message: "internal_error" });
});

const HOST = (process.env.HOST || "0.0.0.0").trim() || "0.0.0.0";
const PORT_ENV = (process.env.PORT || "").trim();
const PORT = Number(PORT_ENV || config.PORT || 3000);
const REDIS_URL =
  String(process.env.REDIS_URL || "").trim() || "redis://127.0.0.1:6380";
const REDIS_PORT = process.env.REDIS_PORT || "";

const server = app.listen(PORT, HOST, () => {
  console.log(
    `[BOOT] listening on http://${HOST}:${PORT} (PORT env=${PORT_ENV || "n/a"})`,
  );
  console.log(`redis connecting to ${REDIS_URL}`);
  console.log("[env]", { HOST, PORT, REDIS_URL, REDIS_PORT });
});

server.on("error", (err: NodeJS.ErrnoException) => {
  if (err?.code === "EADDRINUSE") {
    console.error(`[BOOT][ERROR] Port ${PORT} is in use`);
    console.error("[BOOT][HINT] Run: npm run port:3000");
    console.error(
      "[BOOT][HINT] Then free port quickly: npm run port:3000:kill",
    );
    process.exit(1);
  }
  console.error("[BOOT][ERROR] server listen failed", err);
  process.exit(1);
});

export default app;
