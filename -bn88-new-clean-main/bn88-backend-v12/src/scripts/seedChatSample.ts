import * as fs from "node:fs";
import * as path from "node:path";
import dotenv from "dotenv";
import { PrismaClient } from "@prisma/client";

const envCandidates = [
  path.resolve(process.cwd(), ".env"),
  path.resolve(process.cwd(), "bn88-backend-v12/.env"),
];
const envPath = envCandidates.find((p) => fs.existsSync(p));
dotenv.config(envPath ? { path: envPath } : undefined);

if (!process.env.DATABASE_URL) {
  process.env.DATABASE_URL = `file:${path.resolve(process.cwd(), "prisma/dev.db")}`;
}

const prisma = new PrismaClient();

async function main() {
  const tenant = process.env.TENANT_DEFAULT || "bn9";

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
    throw new Error(`[seed:chat] no bot found for tenant=${tenant}`);
  }

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
