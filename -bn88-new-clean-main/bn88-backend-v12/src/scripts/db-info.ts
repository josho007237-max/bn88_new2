import * as fs from "node:fs";
import * as path from "node:path";
import dotenv from "dotenv";
import { PrismaClient } from "@prisma/client";

// Usage: set DATABASE_URL=file:./prisma/dev.db before running `npm run db:info`.

function resolveRepoRoot(startDir: string): string {
  let dir = startDir;
  while (true) {
    const hasBackend = fs.existsSync(path.join(dir, "bn88-backend-v12"));
    const hasWorkplan = fs.existsSync(path.join(dir, "WORKPLAN_MASTER.md"));
    if (hasBackend && hasWorkplan) return dir;

    const parent = path.dirname(dir);
    if (parent === dir) return startDir;
    dir = parent;
  }
}

function resolveDbFilePath(dbUrl: string, cwd: string): string | null {
  if (!dbUrl.startsWith("file:")) return null;
  const raw = dbUrl.slice("file:".length);
  if (!raw) return null;
  return path.isAbsolute(raw) ? raw : path.resolve(cwd, raw);
}

const cwd = process.cwd();
const repoRoot = resolveRepoRoot(cwd);
const backendRoot = fs.existsSync(path.join(repoRoot, "bn88-backend-v12"))
  ? path.join(repoRoot, "bn88-backend-v12")
  : cwd;

const envCandidates = [
  path.resolve(cwd, ".env"),
  path.resolve(cwd, "bn88-backend-v12/.env"),
  path.resolve(backendRoot, ".env"),
];
const envPath = envCandidates.find((p) => fs.existsSync(p));
dotenv.config(envPath ? { path: envPath } : undefined);

const dbUrlRaw = String(process.env.DATABASE_URL || "").trim();
const dbUrl = dbUrlRaw || "MISSING";

if (!process.env.DATABASE_URL) {
  process.env.DATABASE_URL = `file:${path.resolve(backendRoot, "prisma/dev.db")}`;
}

const prisma = new PrismaClient();

async function main() {
  console.log(`[db:info] cwd=${cwd}`);
  console.log(`[db:info] DATABASE_URL=${dbUrl}`);

  const dbFilePath = dbUrlRaw ? resolveDbFilePath(dbUrlRaw, cwd) : null;
  if (dbFilePath) {
    if (fs.existsSync(dbFilePath)) {
      console.log(`[db:info] dbFile=${dbFilePath}`);
      console.log(`[db:info] dbFileSizeBytes=${fs.statSync(dbFilePath).size}`);
    } else {
      console.log(`[db:info] dbFile=${dbFilePath}`);
      console.log("[db:info] dbFileSizeBytes=missing");
    }
  } else {
    console.log("[db:info] dbFile=not_file_url_or_missing");
  }

  const countAll = await prisma.chatSession.count();
  const countBn9 = await prisma.chatSession.count({ where: { tenant: "bn9" } });
  const bots = await prisma.bot.findMany({
    take: 5,
    select: { id: true, tenant: true, platform: true, active: true },
    orderBy: { createdAt: "desc" },
  });

  console.log(`[db:info] chatSession.count=${countAll}`);
  console.log(`[db:info] chatSession.count(tenant=bn9)=${countBn9}`);
  console.log(`[db:info] bots.take5=${JSON.stringify(bots)}`);
}

main()
  .catch((err) => {
    console.error("[db:info] ERROR", err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
