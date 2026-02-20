// src/mw/auth.ts
import type { Request, Response, NextFunction } from "express";
import { verifyJwt } from "../lib/jwt";
import { getRequestId } from "../utils/logger";

export type AuthPayload = {
  sub: string;
  email: string;
  roles: string[];
  tokenType?: string;
};

export type AdminSession = AuthPayload & { id: string };

declare module "express-serve-static-core" {
  interface Request {
    auth?: AdminSession;
    // legacy field (kept for compatibility only)
    admin?: AdminSession;
  }
}

type TokenSource = "header" | "cookie" | "query" | "none";

const QUERY_TOKEN_ALLOWED_PREFIXES = ["/api/live/", "/api/admin/chat/line-content/"];

function isQueryTokenAllowed(req: Request): boolean {
  const url = (req.originalUrl || req.url || "").trim();
  return QUERY_TOKEN_ALLOWED_PREFIXES.some((prefix) => url.startsWith(prefix));
}

function readQueryToken(req: Request): string {
  const q: Record<string, unknown> = (req.query ?? {}) as Record<string, unknown>;
  const raw =
    q.token ??
    q.access_token ??
    q.accessToken ??
    q.auth_token ??
    q.authToken ??
    "";
  return typeof raw === "string"
    ? raw.trim()
    : Array.isArray(raw)
      ? String(raw[0] ?? "").trim()
      : "";
}

function readCookieToken(req: Request): string {
  const cookies = (req as any).cookies;
  return typeof cookies?.bn88_token === "string" ? cookies.bn88_token.trim() : "";
}

function isLivePath(req: Request): boolean {
  const path = `${req.path || req.url || ""}`.trim();
  return path.startsWith("/api/live/");
}

function deriveLiveTenant(req: Request): string | undefined {
  const fromParams = `${(req.params as any)?.tenant || ""}`.trim();
  if (fromParams) return fromParams;

  const path = `${req.path || req.url || ""}`.trim();
  const match = path.match(/^\/api\/live\/([^/?#]+)/i);
  return match?.[1]?.trim() || undefined;
}

function getToken(req: Request): {
  token: string;
  raw: string;
  source: TokenSource;
  queryProvided: boolean;
  queryAllowed: boolean;
} {
  const rawHeader = String(req.headers.authorization || req.get("authorization") || "");
  if (rawHeader) {
    const lower = rawHeader.toLowerCase();
    if (lower.startsWith("bearer ")) {
      const token = rawHeader.slice(7).trim();
      const tokenLower = token.toLowerCase();
      if (token && tokenLower !== "undefined" && tokenLower !== "null") {
        return {
          token,
          raw: rawHeader.trim(),
          source: "header",
          queryProvided: false,
          queryAllowed: false,
        };
      }
    }
  }

  const queryToken = readQueryToken(req);
  const queryProvided = Boolean(queryToken);
  const queryAllowed = queryProvided ? isQueryTokenAllowed(req) : false;
  if (queryToken && queryAllowed) {
    return { token: queryToken, raw: "", source: "query", queryProvided, queryAllowed };
  }

  const cookieToken = readCookieToken(req);
  if (cookieToken) {
    return { token: cookieToken, raw: "", source: "cookie", queryProvided, queryAllowed };
  }

  return { token: "", raw: "", source: "none", queryProvided, queryAllowed };
}

function toDebugAuth(payload?: Partial<AuthPayload> & { id?: string }) {
  if (!payload) return undefined;
  return {
    id: payload.id || payload.sub,
    sub: payload.sub,
    email: payload.email,
    roles: Array.isArray(payload.roles) ? payload.roles : [],
    tokenType: payload.tokenType,
  };
}

export function authGuard(req: Request, res: Response, next: NextFunction) {
  const route = `${req.method} ${req.originalUrl || req.url}`.trim();
  const tenant =
    ((req.headers["x-tenant"] as string | undefined) ?? "").trim() ||
    (isLivePath(req) ? deriveLiveTenant(req) : undefined);

  if (!(req.headers["x-tenant"] as string | undefined)?.trim() && tenant) {
    req.headers["x-tenant"] = tenant;
  }
  const requestId = getRequestId(req);
  const DEBUG_AUTH_LOG = process.env.DEBUG_AUTH === "1";
  const { token, raw, source, queryProvided, queryAllowed } = getToken(req);
  const hasAuthHeader = source === "header";
  const authHeaderPrefix = hasAuthHeader ? raw.split(/\s+/)[0] : undefined;
  const tokenPartsCount = token ? token.split(".").length : 0;

  const logAuthDebug = (
    reason: string,
    extra: Record<string, unknown> = {}
  ) => {
    if (!DEBUG_AUTH_LOG) return;
    console.info("[DEBUG_AUTH]", reason, {
      guard: "authGuard",
      path: route,
      requestId,
      tenant,
      hasAuthHeader,
      authHeaderPrefix,
      tokenPartsCount,
      tokenSource: source,
      queryProvided,
      queryAllowed,
      reqAuth: toDebugAuth((req as any).auth),
      ...extra,
    });
  };

  if (queryProvided && !queryAllowed && source === "none") {
    logAuthDebug("query_token_not_allowed");
  }

  if (!token) {
    logAuthDebug("missing_token");
    return res.status(401).json({ ok: false, error: "missing_token" });
  }

  if (tokenPartsCount !== 3) {
    logAuthDebug("malformed_token");
    return res
      .status(401)
      .json({ ok: false, error: "invalid_token", reason: "malformed" });
  }

  try {
    const payload = verifyJwt<AuthPayload & { adminId?: string; id?: string }>(
      token,
    );
    const sub =
      payload.sub ||
      (payload as any).adminId ||
      (payload as any).id ||
      "";
    const roles = Array.isArray(payload.roles)
      ? payload.roles
      : payload.roles
        ? [String(payload.roles)]
        : [];
    const session = {
      ...payload,
      sub,
      roles,
      id: sub,
    } as AuthPayload & { id: string };

    (req as any).auth = session;
    // keep alias during migration to single auth source
    (req as any).admin = session;
    logAuthDebug("ok", {
      tokenSource: source,
      decoded: toDebugAuth(session),
      reqAuth: toDebugAuth(session),
    });
    return next();
  } catch (err) {
    logAuthDebug("invalid_signature");
    console.error("authGuard invalid token:", err);
    return res.status(401).json({ ok: false, error: "invalid_token" });
  }
}
