require("dotenv").config();
const { PrismaClient } = require("@prisma/client");
const p = new PrismaClient();

(async () => {
  const botId = process.env.BOT_ID;
  const secret = process.env.CHANNEL_SECRET;
  const token = process.env.CHANNEL_ACCESS_TOKEN;

  if (!botId) throw new Error("BOT_ID missing in .env");
  if (!secret) throw new Error("CHANNEL_SECRET missing in .env");
  if (!token) throw new Error("CHANNEL_ACCESS_TOKEN missing in .env");

  await p.botSecret.upsert({
    where: { botId },
    update: { channelSecret: secret, channelAccessToken: token },
    create: { botId, channelSecret: secret, channelAccessToken: token },
  });

  console.log("OK: botSecret set for", botId);
})()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(async () => { await p.$disconnect(); });
