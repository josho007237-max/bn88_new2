import * as fs from "node:fs";
import * as path from "node:path";
import dotenv from "dotenv";
import { PrismaClient } from "@prisma/client";

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

const fallbackDbPath = path.resolve(backendRoot, "prisma/dev.db");
if (!process.env.DATABASE_URL) {
  process.env.DATABASE_URL = `file:${fallbackDbPath}`;
}

const prisma = new PrismaClient();

async function main() {
  const tenant = process.env.TENANT_DEFAULT || "bn9";
  const dbUrl = String(process.env.DATABASE_URL || "").trim() || "(not set)";

  console.log(`[seed:chat] cwd=${cwd}`);
  console.log(`[seed:chat] DATABASE_URL=${dbUrl}`);
  const dbFilePath = resolveDbFilePath(dbUrl, cwd);
  if (dbFilePath) {
    if (fs.existsSync(dbFilePath)) {
      console.log(`[seed:chat] dbFile=${dbFilePath}`);
      console.log(`[seed:chat] dbFileSizeBytes=${fs.statSync(dbFilePath).size}`);
    } else {
      console.log(`[seed:chat] dbFile=${dbFilePath}`);
      console.log("[seed:chat] dbFileSizeBytes=missing");
    }
  } else {
    console.log("[seed:chat] dbFile=not_file_url");
  }
  if (dbUrl === `file:${fallbackDbPath}`) {
    console.log(`[seed:chat] fallback DB path=${fallbackDbPath}`);
  }

  const sessionCount = await prisma.chatSession.count();
  if (sessionCount > 0) {
    console.log(`[seed:chat] skip: existing ChatSession count=${sessionCount}`);
    return;
  }

  const bot = await prisma.bot.findFirst({
    where: {
      tenant,
      OR: [{ platform: "line" }, { active: true }],
    },
    orderBy: { createdAt: "asc" },
    select: { id: true, platform: true },
  });

  if (!bot) {
    throw new Error(
      `[seed:chat] no bot found for tenant=${tenant}. Please run \"npm run seed:dev\" first, or create a Bot for tenant=${tenant} with platform=line.`
    );
  }

  console.log(
    `[seed:chat] selected tenant=${tenant} botId=${bot.id} platform=${bot.platform || "line"}`
  );

  const now = new Date();
  const userId = `U_DUMMY_${Date.now()}`;

  const session = await prisma.chatSession.create({
    data: {
      tenant,
      botId: bot.id,
      platform: bot.platform || "line",
      userId,
      displayName: "Sample User",
      firstMessageAt: now,
      lastMessageAt: now,
      lastText: "hello",
      lastDirection: "user",
      unread: 1,
    },
    select: { id: true },
  });

  await prisma.chatMessage.create({
    data: {
      tenant,
      botId: bot.id,
      platform: bot.platform || "line",
      sessionId: session.id,
      senderType: "user",
      text: "hello",
      platformMessageId: `seed-msg-${Date.now()}`,
    },
  });

  await prisma.chatSession.update({
    where: { id: session.id },
    data: {
      lastMessageAt: now,
      lastText: "hello",
      lastDirection: "user",
    },
  });

  console.log(`[seed:chat] created sessionId=${session.id}`);
}

main()
  .catch((err) => {
    console.error("[seed:chat] ERROR", err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
