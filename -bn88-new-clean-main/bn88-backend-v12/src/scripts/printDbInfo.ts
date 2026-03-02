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
  const dbUrl = String(process.env.DATABASE_URL || "").trim() || "(not set)";
  const dbFilePath = resolveDbFilePath(dbUrl, cwd);

  console.log(`[db:info] cwd=${cwd}`);
  console.log(`[db:info] DATABASE_URL=${dbUrl}`);

  if (dbFilePath) {
    if (fs.existsSync(dbFilePath)) {
      const size = fs.statSync(dbFilePath).size;
      console.log(`[db:info] dbFile=${dbFilePath}`);
      console.log(`[db:info] dbFileSizeBytes=${size}`);
    } else {
      console.log(`[db:info] dbFile=${dbFilePath}`);
      console.log("[db:info] dbFileSizeBytes=missing");
    }
  } else {
    console.log("[db:info] dbFile=not_file_url");
  }

  const countAll = await prisma.chatSession.count();
  const countBn9 = await prisma.chatSession.count({ where: { tenant: "bn9" } });
  console.log(`[db:info] chatSession.count=${countAll}`);
  console.log(`[db:info] chatSession.count(tenant=bn9)=${countBn9}`);
}

main()
  .catch((err) => {
    console.error("[db:info] ERROR", err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
