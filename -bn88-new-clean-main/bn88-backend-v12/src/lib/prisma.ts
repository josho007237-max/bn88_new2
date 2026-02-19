// src/lib/prisma.ts
/**
 * Prisma Client singleton (กัน new ซ้ำตอน dev/tsx watch)
 * - import { prisma } from "../lib/prisma"
 * - dev: เปิด log พอประมาณ, eager connect ได้
 * - production: ลด log, ไม่สร้าง instance ซ้ำ
 * - มี graceful shutdown ที่ลงทะเบียนครั้งเดียว
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { PrismaClient } from "@prisma/client";

const isDev = process.env.NODE_ENV !== "production";
const BACKEND_ROOT = path.resolve(__dirname, "../..");

function resolveSqliteFilePath(urlRaw?: string): string | null {
  const url = String(urlRaw || "").trim();
  if (!url.toLowerCase().startsWith("file:")) return null;

  const withoutScheme = url.slice(5).split("?")[0].trim();
  if (!withoutScheme || withoutScheme == ":memory:") return null;

  if (path.isAbsolute(withoutScheme)) {
    return path.normalize(withoutScheme);
  }

  return path.resolve(BACKEND_ROOT, withoutScheme);
}

function ensureSqliteFileReady() {
  const sqlitePath = resolveSqliteFilePath(process.env.DATABASE_URL);
  if (!sqlitePath) return;

  const dir = path.dirname(sqlitePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
    console.log(`[prisma] created sqlite dir: ${dir}`);
  }

  if (!fs.existsSync(sqlitePath) && isDev) {
    fs.closeSync(fs.openSync(sqlitePath, "a"));
    console.log(`[prisma] created sqlite file: ${sqlitePath}`);
  }

  console.log(`[prisma] sqlite path: ${sqlitePath}`);
}

ensureSqliteFileReady();

/**
 * ประกาศ global สำหรับกันซ้ำ (เฉพาะ runtime Node.js)
 * หมายเหตุ: ต้องใช้ declare global เพื่อให้ TypeScript รู้จัก
 */
declare global {
  // eslint-disable-next-line no-var
  var __PRISMA__: PrismaClient | undefined;
  // eslint-disable-next-line no-var
  var __PRISMA_SHUTDOWN_REGISTERED__: boolean | undefined;
}

/** สร้าง/ดึง instance เดิม */
export const prisma =
  global.__PRISMA__ ??
  new PrismaClient({
    log: isDev ? (["info", "warn", "error"] as const) : (["warn", "error"] as const),
  });

/** กันสร้างซ้ำเฉพาะตอน dev */
if (isDev) {
  global.__PRISMA__ = prisma;
}

/** (ทางเลือก) เชื่อมต่อทันทีตอน dev เพื่อเจอปัญหาตั้งแต่ตอนบูต */
if (isDev) {
  prisma
    .$connect()
    .then(() => console.log("[prisma] connected"))
    .catch((err: any) => console.error("[prisma] connect error:", err));
}

/** Graceful shutdown (ลงทะเบียนครั้งเดียวต่อโปรเซส) */
function registerShutdownOnce() {
  if (global.__PRISMA_SHUTDOWN_REGISTERED__) return;
  global.__PRISMA_SHUTDOWN_REGISTERED__ = true;

  const shutdown = async (signal?: string) => {
    try {
      console.log(`[prisma] disconnecting${signal ? " (" + signal + ")" : ""}...`);
      await prisma.$disconnect();
      console.log("[prisma] disconnected");
    } catch (e) {
      console.error("[prisma] disconnect error:", e);
    } finally {
      if (signal) process.exit(0);
    }
  };

  process.on("SIGINT", () => shutdown("SIGINT"));
  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("beforeExit", () => shutdown("beforeExit"));
  process.on("exit", () => console.log("[prisma] process.exit"));
}
registerShutdownOnce();

export default prisma;



