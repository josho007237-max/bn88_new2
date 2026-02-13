require("dotenv").config();
const { PrismaClient } = require("@prisma/client");

const prisma = new PrismaClient();

(async () => {
  const botId = process.env.BOT_ID;
  const tenant = process.env.DEFAULT_TENANT;
  const channelSecret = process.env.CHANNEL_SECRET;
  const channelAccessToken = process.env.CHANNEL_ACCESS_TOKEN;

  if (!botId) throw new Error("BOT_ID missing in .env");
  if (!tenant) throw new Error("DEFAULT_TENANT missing in .env");
  if (!channelSecret) throw new Error("CHANNEL_SECRET missing in .env");
  if (!channelAccessToken)
    throw new Error("CHANNEL_ACCESS_TOKEN missing in .env");

  // 1) Bot (ตัวแม่)
  await prisma.bot.upsert({
    where: { id: botId },
    update: { tenant, platform: "line", active: true },
    create: {
      id: botId,
      tenant,
      name: `line-${botId.slice(0, 6)}`,
      platform: "line",
      active: true,
    },
  });

  // 2) BotConfig
  await prisma.botConfig.upsert({
    where: { botId },
    update: { tenant },
    create: {
      botId,
      tenant,
      model: "gpt-4o-mini",
      temperature: 0.3,
      topP: 1,
      maxTokens: 800,
      aiEnabled: false,
    },
  });

  // 3) BotSecret
  await prisma.botSecret.upsert({
    where: { botId },
    update: { channelSecret, channelAccessToken },
    create: { botId, channelSecret, channelAccessToken },
  });

  console.log("OK: seeded bot + botConfig + botSecret", { botId, tenant });
})()
  .catch((e) => {
    console.error("SEED ERROR:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
