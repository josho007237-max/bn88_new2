import * as fs from "node:fs";
import * as net from "node:net";
import * as path from "node:path";

type PreflightResult = {
  sqlitePath?: string;
  prismaWritable: boolean;
  redisReachable: boolean;
  redisHost: string;
  redisPort: number;
  redisEnabled: boolean;
};

function resolveSqlitePath(databaseUrl: string): string | null {
  const raw = String(databaseUrl || "").trim();
  if (!raw.toLowerCase().startsWith("file:")) return null;
  const rel = raw.slice(5).split("?")[0].trim();
  if (!rel || rel === ":memory:") return null;
  const backendRoot = path.resolve(__dirname, "../..");
  return path.isAbsolute(rel) ? path.normalize(rel) : path.resolve(backendRoot, rel);
}

function checkWritableDir(dirPath: string): boolean {
  try {
    fs.mkdirSync(dirPath, { recursive: true });
    fs.accessSync(dirPath, fs.constants.W_OK);
    const probe = path.join(dirPath, ".write-test.tmp");
    fs.writeFileSync(probe, "ok", { encoding: "utf8" });
    fs.unlinkSync(probe);
    return true;
  } catch (err) {
    console.warn(`[preflight] prisma dir is not writable: ${dirPath}`, err);
    return false;
  }
}

function resolveRedisTarget() {
  const redisUrl = String(process.env.REDIS_URL || "").trim();
  if (redisUrl) {
    try {
      const parsed = new URL(redisUrl);
      return {
        host: parsed.hostname || "127.0.0.1",
        port: Number(parsed.port || 6379),
      };
    } catch {
      // fallback below
    }
  }
  return {
    host: String(process.env.REDIS_HOST || "127.0.0.1").trim() || "127.0.0.1",
    port: Number(process.env.REDIS_PORT || 6380),
  };
}

async function canConnect(host: string, port: number): Promise<boolean> {
  return new Promise((resolve) => {
    const socket = net.createConnection({ host, port });
    let settled = false;
    const done = (ok: boolean) => {
      if (settled) return;
      settled = true;
      socket.destroy();
      resolve(ok);
    };

    socket.setTimeout(800);
    socket.on("connect", () => done(true));
    socket.on("timeout", () => done(false));
    socket.on("error", () => done(false));
  });
}

export async function runDevPreflight(): Promise<PreflightResult> {
  const sqlitePath = resolveSqlitePath(String(process.env.DATABASE_URL || ""));
  const prismaDir = sqlitePath
    ? path.dirname(sqlitePath)
    : path.resolve(__dirname, "../../prisma");
  const prismaWritable = checkWritableDir(prismaDir);

  const redisSkipFlag =
    process.env.DISABLE_REDIS === "1" || process.env.ENABLE_REDIS === "0";
  const redisEnabled = !redisSkipFlag;
  const redisTarget = resolveRedisTarget();

  let redisReachable = false;
  if (redisEnabled) {
    redisReachable = await canConnect(redisTarget.host, redisTarget.port);
    if (!redisReachable) {
      console.warn(
        `[preflight] redis unreachable at ${redisTarget.host}:${redisTarget.port}; continuing without queues`,
      );
    }
  } else {
    console.warn("[preflight] redis disabled by env; queues will be skipped");
  }

  if (sqlitePath) {
    console.log(`[preflight] sqlite path: ${sqlitePath}`);
  }

  return {
    sqlitePath: sqlitePath || undefined,
    prismaWritable,
    redisReachable,
    redisHost: redisTarget.host,
    redisPort: redisTarget.port,
    redisEnabled,
  };
}
