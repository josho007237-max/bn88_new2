// src/middleware/basicAuth.ts
import type { Request, Response, NextFunction } from "express";
import { prisma } from "../lib/prisma";
import { createRequestLogger, getRequestId } from "../utils/logger";

export type PermissionName = "manageBots" | "manageCampaigns" | "viewReports";

// ✅ map แบบไม่สนตัวพิมพ์ใหญ่/เล็ก
const ROLE_PERMISSIONS: Record<string, PermissionName[]> = {
  admin: ["manageBots", "manageCampaigns", "viewReports"],
  root: ["manageBots", "manageCampaigns", "viewReports"],
  editor: ["manageBots", "manageCampaigns", "viewReports"],
  viewer: ["viewReports"],
  // superadmin จะ bypass ทั้งหมดใน requirePermission
  superadmin: ["manageBots", "manageCampaigns", "viewReports"],
};

type AuthFromGuard = {
  sub?: string; // userId ถูกเก็บใน sub (มาจาก subject ตอน signJwt)
  id?: string;  // เผื่อบางที่ใช้ id
  email?: string;
  roles?: string[];
  permissions?: string[];
  tokenType?: string;
  [key: string]: any;
};

type AuthSource = "auth" | "admin" | "user" | "none";

function pickAuthContext(req: Request): { auth?: AuthFromGuard; source: AuthSource } {
  const fromAuth = (req as any).auth as AuthFromGuard | undefined;
  if (fromAuth) return { auth: fromAuth, source: "auth" };

  const fromAdmin = (req as any).admin as AuthFromGuard | undefined;
  if (fromAdmin) return { auth: fromAdmin, source: "admin" };

  const fromUser = (req as any).user as AuthFromGuard | undefined;
  if (fromUser) return { auth: fromUser, source: "user" };

  return { auth: undefined, source: "none" };
}

function norm(v: unknown): string {
  return String(v ?? "").trim().toLowerCase();
}

function toDebugAuth(auth?: AuthFromGuard) {
  if (!auth) return undefined;
  return {
    id: auth.id || auth.sub,
    sub: auth.sub,
    email: auth.email,
    roles: Array.isArray(auth.roles) ? auth.roles.map(String) : [],
    permissions: Array.isArray(auth.permissions)
      ? auth.permissions.map(String)
      : [],
    tokenType: auth.tokenType,
  };
}

function permissionsFromRoles(roles?: string[]): Set<PermissionName> {
  const set = new Set<PermissionName>();
  (roles ?? []).forEach((r) => {
    const mapped = ROLE_PERMISSIONS[norm(r)];
    if (mapped) mapped.forEach((p) => set.add(p));
  });
  return set;
}

function permissionsFromClaims(rawPerms?: string[]): Set<PermissionName> {
  const set = new Set<PermissionName>();
  const allowed = new Set<PermissionName>([
    "manageBots",
    "manageCampaigns",
    "viewReports",
  ]);
  (rawPerms ?? []).forEach((perm) => {
    const normalized = String(perm ?? "").trim();
    if (!normalized) return;
    if (allowed.has(normalized as PermissionName)) {
      set.add(normalized as PermissionName);
    }
  });
  return set;
}

async function collectPermissions(adminId: string): Promise<Set<string>> {
  const hasDelegates =
    typeof (prisma as any).adminUserRole?.findMany === "function" &&
    typeof (prisma as any).rolePermission?.findMany === "function";

  if (!hasDelegates) return new Set<string>();

  const user = await prisma.adminUser.findUnique({
    where: { id: adminId },
    include: {
      roles: {
        include: {
          role: { include: { permissions: { include: { permission: true } } } },
        },
      },
    },
  });

  const set = new Set<string>();
  user?.roles?.forEach((link: any) => {
    link.role?.permissions?.forEach((rp: any) => {
      if (rp.permission?.name) set.add(rp.permission.name);
    });
  });
  return set;
}

export function requirePermission(required: PermissionName[]) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const requestId = getRequestId(req);
    const log = createRequestLogger(requestId);

    // ใช้ req.auth เป็นหลัก และ fallback ฟิลด์เดิมเพื่อความเข้ากันได้
    const { auth, source: authSource } = pickAuthContext(req);

    const adminId = auth?.sub || auth?.id; // ✅ รองรับ sub เป็นหลัก
    let roles = (auth?.roles ?? []).map((r) => String(r));
    const authFieldNames = auth ? Object.keys(auth) : [];
    const route = `${req.method} ${req.originalUrl || req.url}`;
    const tenantHeader = ((req.headers["x-tenant"] as string | undefined) ?? "").trim();
    const authorizationHeader = req.headers.authorization;
    const hasToken =
      typeof authorizationHeader === "string" &&
      authorizationHeader.trim().toLowerCase().startsWith("bearer ");
    const DEBUG_PERMISSION_LOG = process.env.DEBUG === "1";
    const DEBUG_AUTH_LOG = process.env.DEBUG_AUTH === "1";
    const logAuthState = (reason: string, extra: Record<string, unknown> = {}) => {
      if (!DEBUG_AUTH_LOG) return;
      log.info("[requirePermission] auth deny", {
        guard: "requirePermission",
        reason,
        route,
        tenant: tenantHeader || undefined,
        hasToken,
        adminId,
        roles,
        authSource,
        reqAuth: toDebugAuth(auth),
        ...extra,
      });
    };
    const debugFieldTrace = (reason: string, extra: Record<string, unknown> = {}) => {
      if (!DEBUG_PERMISSION_LOG) return;
      log.info("[requirePermission] debug deny", {
        reason,
        adminId,
        roles,
        authSource,
        permissions: auth?.permissions,
        authFields: authFieldNames,
        ...extra,
      });
    };
    if (DEBUG_AUTH_LOG) {
      log.info("[DEBUG_AUTH] requirePermission run", {
        guard: "requirePermission",
        route,
        required,
        tenant: tenantHeader || undefined,
        authSource,
        reqAuth: toDebugAuth(auth),
      });
    }

    if (!roles.length && (auth?.tokenType === "admin-api" || (auth as any)?.type === "admin")) {
      roles = ["Admin"];
    }

    const rolesLower = new Set(roles.map(norm));

    // ✅ superadmin ผ่านทุก permission
    if (rolesLower.has("superadmin")) return next();

    try {
      // 1) เช็คจาก permission claim ใน token ก่อน (เป็นแหล่งหลักตาม authGuard)
      const directPerms = permissionsFromClaims((auth?.permissions ?? []).map(String));
      if (directPerms.size > 0 && required.some((perm) => directPerms.has(perm))) {
        if (DEBUG_AUTH_LOG) {
          log.info("[DEBUG_AUTH] requirePermission allow", {
            guard: "requirePermission",
            route,
            authSource,
            decision: "token_permissions",
            required,
            granted: Array.from(directPerms),
          });
        }
        return next();
      }

      // 1.1) fallback role claim ใน token
      const claimPerms = permissionsFromRoles(roles);
      if (claimPerms.size > 0 && required.some((perm) => claimPerms.has(perm))) {
        if (DEBUG_AUTH_LOG) {
          log.info("[DEBUG_AUTH] requirePermission allow", {
            guard: "requirePermission",
            route,
            authSource,
            decision: "token_roles",
            required,
            granted: Array.from(claimPerms),
          });
        }
        return next();
      }

      if (!adminId) {
        logAuthState("missing_adminId");
        debugFieldTrace("missing_adminId");
        return res.status(401).json({
          ok: false,
          code: "UNAUTHENTICATED",
          message: "unauthorized",
          required,
          have: {
            permissions: Array.from(directPerms),
            roles,
          },
        });
      }

      // 2) ถ้ายังไม่พอ → เช็คจาก DB (RBAC)
      const canCheckDb =
        typeof (prisma as any).role?.count === "function" &&
        typeof (prisma as any).adminUserRole?.count === "function";

      if (canCheckDb) {
        // โหมด dev: ถ้ายังไม่มี role/assignment เลย ให้ผ่าน
        const [totalRoles, totalAssignments] = await Promise.all([
          prisma.role.count(),
          prisma.adminUserRole.count(),
        ]);
        if (totalRoles === 0 || totalAssignments === 0) return next();
      }

      const granted = await collectPermissions(String(adminId));
      if (granted.size === 0) {
        logAuthState("rbac_empty");
        debugFieldTrace("rbac_empty");
        log.warn("RBAC deny: no permissions for admin", adminId);
        return res.status(403).json({
          ok: false,
          code: "FORBIDDEN",
          message: "forbidden",
          required,
          have: {
            permissions: Array.from(directPerms),
            roles,
            rbac: Array.from(granted),
          },
        });
      }

      const ok = required.some((perm) => granted.has(perm));
      if (!ok) {
        logAuthState("rbac_missing_permission", {
          granted: Array.from(granted),
        });
        debugFieldTrace("rbac_missing_permission", {
          granted: Array.from(granted),
        });
        log.warn("RBAC deny: missing permission", { required, adminId });
        return res.status(403).json({
          ok: false,
          code: "FORBIDDEN",
          message: "forbidden",
          required,
          have: {
            permissions: Array.from(directPerms),
            roles,
            rbac: Array.from(granted),
          },
        });
      }

      if (DEBUG_AUTH_LOG) {
        log.info("[DEBUG_AUTH] requirePermission allow", {
          guard: "requirePermission",
          route,
          authSource,
          decision: "rbac",
          required,
          granted: Array.from(granted),
        });
      }

      return next();
    } catch (err) {
      log.error("RBAC error", err);
      return res.status(500).json({ ok: false, message: "rbac_error" });
    }
  };
}
