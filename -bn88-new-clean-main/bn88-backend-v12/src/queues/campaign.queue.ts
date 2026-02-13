import { Queue, Worker, JobsOptions } from "bullmq";
import { createRequestLogger } from "../utils/logger";
import { queueCampaign } from "../services/lepClient";

const redisUrl =
  String(process.env.REDIS_URL || "").trim() || "redis://127.0.0.1:6380";
const redisSkipFlag = process.env.DISABLE_REDIS === "1" || process.env.ENABLE_REDIS === "0";
const redisEnabled = Boolean(redisUrl) && !redisSkipFlag;
const connection = redisEnabled
  ? {
      url: redisUrl,
      retryStrategy: (times: number) => Math.min(times * 5000, 60_000),
    }
  : null;
const queueName = "lep-campaign";
const redisLog = createRequestLogger("redis");
let redisDisabledWarned = false;
let redisConnectedLogged = false;
const redisDisabledMessage = redisSkipFlag
  ? "[redis] disabled via DISABLE_REDIS=1 or ENABLE_REDIS=0."
  : "[redis] disabled.";

function warnRedisDisabled() {
  if (redisDisabledWarned) return;
  redisDisabledWarned = true;
  redisLog.warn(redisDisabledMessage);
}

export type CampaignScheduleJob = {
  scheduleId: string;
  campaignId: string;
  requestId?: string;
};

let queueInstance: Queue<CampaignScheduleJob> | null = null;
let workerStarted = false;
let heartbeatTimer: NodeJS.Timeout | null = null;

function startHeartbeat() {
  if (heartbeatTimer) return;
  heartbeatTimer = setInterval(() => {
    redisLog.info("[campaign.queue] heartbeat", { queue: queueName });
  }, 60_000);
}

function getQueue() {
  if (!redisEnabled) {
    warnRedisDisabled();
    return null;
  }
  if (!queueInstance) {
    queueInstance = new Queue<CampaignScheduleJob>(queueName, {
      connection: connection!,
    });
  }
  return queueInstance;
}

export async function upsertCampaignScheduleJob(
  job: CampaignScheduleJob & {
    cron: string;
    timezone: string;
    startAt?: Date;
    endAt?: Date;
    idempotencyKey?: string;
  }
) {
  const q = getQueue();
  if (!q) return null;
  const log = createRequestLogger(job.requestId);

  const repeat: JobsOptions["repeat"] = {
    pattern: job.cron,
    tz: job.timezone,
  };

  if (job.startAt) repeat.startDate = job.startAt.getTime();
  if (job.endAt) repeat.endDate = job.endAt.getTime();

  const jobId = job.idempotencyKey || job.scheduleId;

  await q.add(
    "campaign.schedule",
    {
      scheduleId: job.scheduleId,
      campaignId: job.campaignId,
      requestId: job.requestId,
    },
    {
      jobId,
      repeat,
      removeOnComplete: true,
      removeOnFail: true,
    }
  );

  log.info("[campaign.schedule] registered", {
    scheduleId: job.scheduleId,
    campaignId: job.campaignId,
    jobId,
  });
  return jobId;
}

export async function removeCampaignScheduleJob(scheduleId: string) {
  const q = getQueue();
  if (!q) return;
  const repeatables = await q.getRepeatableJobs();
  for (const r of repeatables) {
    if (r.id === scheduleId || r.key.includes(scheduleId)) {
      await q.removeRepeatableByKey(r.key);
    }
  }
}

export function startCampaignScheduleWorker() {
  if (workerStarted) return;
  if (!redisEnabled) {
    warnRedisDisabled();
    return;
  }
  workerStarted = true;
  redisLog.info(`redis connecting to ${redisUrl}`);
  try {
    const worker = new Worker<CampaignScheduleJob>(
      queueName,
      async (job) => {
        const log = createRequestLogger(job.data.requestId || job.id);
        log.info("[campaign.schedule] firing", {
          scheduleId: job.data.scheduleId,
          campaignId: job.data.campaignId,
        });
        try {
          await queueCampaign(job.data.campaignId);
          log.info("[campaign.schedule] queued campaign", {
            campaignId: job.data.campaignId,
          });
        } catch (err) {
          log.error("[campaign.schedule] queue failed", err);
          throw err;
        }
      },
      { connection: connection! }
    );

    worker.on("error", (err) => {
      redisLog.warn("[redis] connection error (retrying with backoff)", err);
    });
    worker.on("ready", () => {
      if (redisConnectedLogged) return;
      redisConnectedLogged = true;
      redisLog.info("redis connected");
      startHeartbeat();
    });

    worker.on("failed", (job, err) => {
      const log = createRequestLogger(job?.data?.requestId || job?.id);
      log.error("[campaign.schedule] worker failed", err);
    });
  } catch (err) {
    workerStarted = false;
    redisLog.warn("[redis] worker start failed (will retry)", err);
    setTimeout(() => startCampaignScheduleWorker(), 10_000);
  }
}
