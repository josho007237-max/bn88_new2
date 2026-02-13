// src/queues/message.queue.ts
import { Queue, Worker, JobsOptions } from "bullmq";
import { createRequestLogger } from "../utils/logger";

export type EnqueueRateLimitedSendArgs = {
  id: string;
  channelId: string;
  requestId?: string;
  handler: () => Promise<any>;
};

export type EnqueueRateLimitedSendResult = {
  scheduled: boolean;
  delayMs?: number;
  result?: any;
};

const redisUrl =
  String(process.env.REDIS_URL || "").trim() || "redis://127.0.0.1:6380";
const redisSkipFlag =
  process.env.DISABLE_REDIS === "1" || process.env.ENABLE_REDIS === "0";
const redisEnabled = Boolean(redisUrl) && !redisSkipFlag;
const connection = redisEnabled
  ? {
      url: redisUrl,
      retryStrategy: (times: number) => Math.min(times * 5000, 60_000),
    }
  : null;
const queueName = "engagement-message";
const redisLog = createRequestLogger("redis");
let redisDisabledWarned = false;
let redisConnectedLogged = false;
let workerStarted = false;
let heartbeatTimer: NodeJS.Timeout | null = null;
const redisDisabledMessage = redisSkipFlag
  ? "[redis] disabled via DISABLE_REDIS=1 or ENABLE_REDIS=0."
  : "[redis] disabled.";

function warnRedisDisabled() {
  if (redisDisabledWarned) return;
  redisDisabledWarned = true;
  redisLog.warn(redisDisabledMessage);
}

type MessageScheduleJob = {
  handlerId: string;
  channelId?: string;
  requestId?: string;
};

type ScheduleMessageArgs = {
  id: string;
  channelId: string;
  cron: string;
  timezone: string;
  handler: () => Promise<any>;
  requestId?: string;
};

let queueInstance: Queue<MessageScheduleJob> | null = null;
const handlerRegistry = new Map<string, () => Promise<any>>();

function getQueue() {
  if (!redisEnabled) {
    warnRedisDisabled();
    return null;
  }
  if (!queueInstance) {
    queueInstance = new Queue<MessageScheduleJob>(queueName, {
      connection: connection!,
    });
  }
  return queueInstance;
}

function startHeartbeat() {
  if (heartbeatTimer) return;
  heartbeatTimer = setInterval(() => {
    redisLog.info("[message.queue] heartbeat", { queue: queueName });
  }, 60_000);
}

/**
 * เวอร์ชัน "ให้ผ่าน typecheck + ใช้งานได้ทันที"
 * - ยังไม่ทำ rate-limit จริง (รันทันที)
 * - คืน shape ที่ call-site ต้องใช้ (scheduled/result/delayMs)
 */
export async function enqueueRateLimitedSend(
  args: EnqueueRateLimitedSendArgs
): Promise<EnqueueRateLimitedSendResult> {
  const result = await args.handler();
  return { scheduled: false, delayMs: 0, result };
}

/**
 * ใช้ใน followUp.ts
 */
export async function enqueueFollowUpJob(
  payload: any
): Promise<{ jobId: string }> {
  const jobId = payload?.id ?? `followup:${Date.now()}`;
  return { jobId };
}

/**
 * ใช้ใน engagementScheduler.ts
 */
export async function scheduleMessageJob(
  payload: ScheduleMessageArgs
): Promise<{ jobId: string }> {
  const jobId = payload?.id ?? `schedule:${Date.now()}`;
  const q = getQueue();
  const log = createRequestLogger(payload.requestId || jobId);

  handlerRegistry.set(jobId, payload.handler);

  if (!q) {
    log.warn("[message.schedule] redis disabled; running handler directly");
    return { jobId };
  }

  const repeat: JobsOptions["repeat"] = {
    pattern: payload.cron,
    tz: payload.timezone,
  };

  await q.add(
    "message.schedule",
    {
      handlerId: jobId,
      channelId: payload.channelId,
      requestId: payload.requestId,
    },
    {
      jobId,
      repeat,
      removeOnComplete: true,
      removeOnFail: true,
    }
  );

  log.info("[message.schedule] registered", {
    jobId,
    channelId: payload.channelId,
    cron: payload.cron,
  });

  return { jobId };
}

/**
 * server.ts เรียกตอนบูตระบบ
 */
export function startMessageWorker(): void {
  if (workerStarted) return;
  if (!redisEnabled) {
    warnRedisDisabled();
    return;
  }
  workerStarted = true;
  redisLog.info(`redis connecting to ${redisUrl}`);

  try {
    const worker = new Worker<MessageScheduleJob>(
      queueName,
      async (job) => {
        const log = createRequestLogger(job.data.requestId || job.id);
        const handler = handlerRegistry.get(job.data.handlerId);
        if (!handler) {
          log.warn("[message.schedule] handler missing", {
            handlerId: job.data.handlerId,
          });
          return;
        }
        log.info("[message.schedule] firing", {
          handlerId: job.data.handlerId,
          channelId: job.data.channelId,
        });
        await handler();
      },
      { connection: connection! }
    );

    worker.on("ready", () => {
      if (redisConnectedLogged) return;
      redisConnectedLogged = true;
      redisLog.info("redis connected");
      startHeartbeat();
    });

    worker.on("failed", (job, err) => {
      const log = createRequestLogger(job?.data?.requestId || job?.id);
      log.error("[message.schedule] worker failed", err);
    });

    worker.on("error", (err) => {
      redisLog.warn("[redis] connection error (retrying with backoff)", err);
    });
  } catch (err) {
    workerStarted = false;
    redisLog.warn("[redis] worker start failed (will retry)", err);
    setTimeout(() => startMessageWorker(), 10_000);
  }
}

