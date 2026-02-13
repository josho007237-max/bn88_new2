import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const tenant = process.env.TENANT_DEFAULT || "bn9";

  let bot = await prisma.bot.findFirst({ where: { tenant, platform: "line" } });
  if (!bot) {
    bot = await prisma.bot.create({
      data: {
        tenant,
        name: "seed-bot-001",
        platform: "line",
        active: true,
      },
    });
  }

  const userId = `seed-user-${Date.now().toString(36)}`;
  const displayName = "Seed User";
  const now = new Date();

  const session = await prisma.chatSession.create({
    data: {
      tenant,
      botId: bot.id,
      platform: bot.platform,
      userId,
      displayName,
      firstMessageAt: now,
      lastMessageAt: now,
      lastText: "hello",
      lastDirection: "user",
    },
  });

  const conversation = await prisma.conversation.upsert({
    where: { botId_userId: { botId: bot.id, userId } },
    update: {},
    create: {
      tenant,
      botId: bot.id,
      userId,
      platform: bot.platform,
    },
  });

  const mockLineMessageId = `mock-${Date.now().toString(36)}`;

  const message = await prisma.chatMessage.create({
    data: {
      tenant,
      botId: bot.id,
      platform: bot.platform,
      sessionId: session.id,
      conversationId: conversation.id,
      senderType: "user",
      type: "TEXT",
      text: "hello",
      attachmentMeta: {
        messageId: mockLineMessageId,
        fileName: "mock.txt",
      },
      platformMessageId: mockLineMessageId,
      meta: { seed: true, mockLineMessageId },
    },
  });

  console.log("Seeded chat session:", {
    tenant,
    botId: bot.id,
    sessionId: session.id,
    messageId: message.id,
    platform: bot.platform,
    userId,
    mockLineMessageId,
  });
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
