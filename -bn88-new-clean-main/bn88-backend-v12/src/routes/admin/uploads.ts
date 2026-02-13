import { Router, type Request } from "express";
import multer from "multer";
import path from "path";
import fs from "fs";
import { prisma } from "../../lib/prisma";

const router = Router();

const UPLOAD_DIR = path.resolve(process.cwd(), "uploads");
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, UPLOAD_DIR),
  filename: (_req, file, cb) => {
    const safe = (Date.now() + "-" + file.originalname).replace(
      /[^\w.\-]+/g,
      "_",
    );
    cb(null, safe);
  },
});

const upload = multer({ storage });

function getActorAdminId(req: Request): string | null {
  const auth = (req as any).auth as { id?: string; sub?: string } | undefined;
  return auth?.id || auth?.sub || null;
}

function getTenant(req: Request): string {
  const tenant = (req.headers["x-tenant"] as string | undefined) ?? "";
  return tenant.trim() || process.env.TENANT_DEFAULT || "bn9";
}

async function writeAuditLog(args: {
  tenant: string;
  actorAdminUserId: string | null;
  action: string;
  target?: string;
  diffJson?: Record<string, unknown>;
}) {
  try {
    await prisma.auditLog.create({
      data: {
        tenant: args.tenant,
        actorAdminUserId: args.actorAdminUserId ?? null,
        action: args.action,
        target: args.target ?? null,
        diffJson: (args.diffJson ?? {}) as any,
      },
    });
  } catch (err) {
    console.error("[auditLog] create failed", err);
  }
}

// ต้องมี POST "/"
router.post("/", upload.single("file"), async (req, res) => {
  const f = req.file;
  if (!f) return res.status(400).json({ ok: false, message: "file_required" });

  await writeAuditLog({
    tenant: getTenant(req),
    actorAdminUserId: getActorAdminId(req),
    action: "upload.create",
    target: f.filename,
    diffJson: {
      originalName: f.originalname,
      size: f.size,
      mime: f.mimetype,
    },
  });

  return res.json({
    ok: true,
    url: `/api/uploads/${f.filename}`,
    filename: f.filename,
    size: f.size,
    mime: f.mimetype,
  });
});

export default router;
