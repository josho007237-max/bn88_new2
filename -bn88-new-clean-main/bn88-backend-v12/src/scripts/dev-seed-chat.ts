import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

function getArg(name: string, fallback: string): string {
  const idx = process.argv.indexOf(`--${name}`);
  if (idx >= 0 && process.argv[idx + 1]) return process.argv[idx + 1];
  return fallback;
}

async function main() {
  const tenant = getArg("tenant", process.env.TENANT_DEFAULT || "bn9");
  const seedUserId = `seed-user-${Date.now()}`;
  const now = new Date();

  const bot = await prisma.bot.findFirst({
    where: { tenant, active: true },
    orderBy: [{ updatedAt: "desc" }, { createdAt: "desc" }],
    select: { id: true, tenant: true, platform: true, name: true },
  });

  if (!bot) {
    throw new Error(`no active bot found for tenant=${tenant}`);
  }

  const session = await prisma.chatSession.create({
    data: {
      tenant,
      botId: bot.id,
      platform: bot.platform || "line",
      userId: seedUserId,
      userName: "seed-user",
      displayName: "Seed User",
      status: "open",
      firstMessageAt: now,
      lastMessageAt: now,
      lastText: "seed inbound message",
      lastDirection: "user",
      unread: 1,
    },
    select: { id: true, userId: true },
  });

  await prisma.chatMessage.create({
    data: {
      tenant,
      botId: bot.id,
      platform: bot.platform || "line",
      sessionId: session.id,
      senderType: "user",
      text: "seed inbound message",
      meta: { source: "dev-seed-chat" },
    },
    select: { id: true },
  });

  console.log(`[dev-seed-chat] OK tenant=${tenant} bot=${bot.name} sessionId=${session.id}`);
}

main()
  .catch((err) => {
    console.error("[dev-seed-chat] ERROR", err instanceof Error ? err.message : err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
