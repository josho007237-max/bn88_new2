import { prisma } from "../lib/prisma";

async function main() {
  const botId = "cmiclfmq000twicgst9oc6k"; // เปลี่ยนเป็น botId ของจริง

  // 1) ลบ row เดิม
  await prisma.botSecret.deleteMany({
    where: { botId },
  });

  // 2) สร้างใหม่พร้อม token
  await prisma.botSecret.create({
    data: {
      botId,
      telegramBotToken: process.env.TELEGRAM_BOT_TOKEN!,
    },
  });

  console.log("[FIXED] BotSecret repaired + token added");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
