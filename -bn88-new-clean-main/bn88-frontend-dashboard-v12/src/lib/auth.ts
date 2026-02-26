export const TOKEN_KEY = "bn9.admin.token";
const LEGACY_TOKEN_KEYS = [
  "BN9_ADMIN_JWT",
  "BN9_TOKEN",
  "bn9_jwt",
  "token",
  "accessToken",
  "authToken",
] as const;

function safeStorage() {
  return (window as any)?.localStorage as Storage | undefined;
}

export function getToken(): string {
  try {
    const storage = safeStorage();
    if (!storage) return "";
    const canonical = storage.getItem(TOKEN_KEY);
    if (canonical) return canonical;

    for (const key of LEGACY_TOKEN_KEYS) {
      const token = storage.getItem(key);
      if (token) return token;
    }

    return "";
  } catch {
    return "";
  }
}

export function setToken(token: string) {
  try {
    const storage = safeStorage();
    if (!storage) return;
    storage.setItem(TOKEN_KEY, token);
    for (const key of LEGACY_TOKEN_KEYS) storage.removeItem(key);
    window.dispatchEvent(new Event("bn9:token-changed"));
  } catch {
    // ignore
  }
}

export function clearToken() {
  try {
    const storage = safeStorage();
    if (!storage) return;
    storage.removeItem(TOKEN_KEY);
    for (const key of LEGACY_TOKEN_KEYS) storage.removeItem(key);
    window.dispatchEvent(new Event("bn9:token-changed"));
  } catch {
    // ignore
  }
}

let migrated = false;

export function migrateLegacyTokenOnBoot() {
  if (migrated) return;
  migrated = true;

  try {
    const storage = safeStorage();
    if (!storage) return;
    const current = storage.getItem(TOKEN_KEY);
    if (current) {
      for (const key of LEGACY_TOKEN_KEYS) storage.removeItem(key);
      return;
    }

    for (const key of LEGACY_TOKEN_KEYS) {
      const legacy = storage.getItem(key);
      if (!legacy) continue;
      storage.setItem(TOKEN_KEY, legacy);
      break;
    }

    for (const key of LEGACY_TOKEN_KEYS) storage.removeItem(key);
  } catch {
    // ignore
  }
}
