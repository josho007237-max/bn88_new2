import { Router, type Request, type Response } from "express";
import { z } from "zod";
import { prisma } from "../../lib/prisma";
import { requirePermission } from "../../middleware/basicAuth";

const router = Router();

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

const assignSchema = z.object({
  adminId: z.string().min(1),
  roleId: z.string().min(1),
});

router.get(
  "/permissions",
  requirePermission(["manageBots"]),
  async (_req, res) => {
    const items = await prisma.permission.findMany({
      orderBy: { name: "asc" },
    });
    return res.json({ ok: true, items });
  },
);

router.get(
  "/admin-users",
  requirePermission(["manageBots"]),
  async (_req, res) => {
    const admins = await prisma.adminUser.findMany({
      select: {
        id: true,
        email: true,
        roles: {
          select: {
            role: {
              select: {
                id: true,
                name: true,
              },
            },
          },
        },
      },
      orderBy: { createdAt: "asc" },
    });

    const items = admins.map((a) => ({
      id: a.id,
      email: a.email,
      roles: a.roles.map((r) => r.role),
    }));

    return res.json({ ok: true, items });
  },
);

router.get(
  "/",
  requirePermission(["manageBots"]),
  async (_req: Request, res: Response) => {
    const roles = await prisma.role.findMany({
      orderBy: { name: "asc" },
      include: { permissions: { include: { permission: true } } },
    });

    const items = roles.map((r) => ({
      id: r.id,
      name: r.name,
      description: r.description,
      permissions: r.permissions.map((p) => p.permission?.name).filter(Boolean),
    }));

    return res.json({ ok: true, items });
  },
);

router.post(
  "/assign",
  requirePermission(["manageBots"]),
  async (req: Request, res: Response) => {
    const parsed = assignSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      return res
        .status(400)
        .json({
          ok: false,
          message: "invalid_input",
          issues: parsed.error.issues,
        });
    }

    const { adminId, roleId } = parsed.data;

    const admin = await prisma.adminUser.findUnique({ where: { id: adminId } });
    if (!admin)
      return res.status(404).json({ ok: false, message: "admin_not_found" });

    const role = await prisma.role.findUnique({ where: { id: roleId } });
    if (!role)
      return res.status(404).json({ ok: false, message: "role_not_found" });

    await prisma.adminUserRole.upsert({
      where: { adminId_roleId: { adminId, roleId } },
      update: {},
      create: { adminId, roleId },
    });

    await writeAuditLog({
      tenant: getTenant(req),
      actorAdminUserId: getActorAdminId(req),
      action: "role.assign",
      target: adminId,
      diffJson: { roleId },
    });

    return res.json({ ok: true, adminId, roleId });
  },
);

export default router;
