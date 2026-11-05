/**
 * Session token + user-level config (~/.pi/kagi.json). No pi imports.
 *
 * kagi.json holds the Kagi session cookie, profile cache, per-session thread
 * state and the spend cap. It is written atomically with mode 0600.
 */
import { randomUUID } from "node:crypto";
import fsp from "node:fs/promises";
import path from "node:path";

export const CONFIG_REL = ".pi/kagi.json";
export const TOKEN_FILE_REL = ".kagi_session_token";
/** Thread entries kept in kagi.json (most recently updated first). */
export const MAX_THREADS = 200;

/**
 * Normalise a pasted token. Kagi "session links" look like
 * https://kagi.com/search?token=<value>; the cookie value is that parameter.
 * Returns null for empty or unusable input.
 */
export function normalizeSessionToken(input) {
  const s = String(input ?? "").trim();
  if (!s) return null;
  if (/^https?:\/\//i.test(s)) {
    try {
      const token = new URL(s).searchParams.get("token");
      return token && token.trim() ? token.trim() : null;
    } catch {
      return null;
    }
  }
  return s;
}

async function readTextOrNull(file, readFile) {
  try {
    const text = await (readFile ? readFile(file) : fsp.readFile(file, "utf8"));
    return text ?? null;
  } catch {
    return null;
  }
}

function homeOf(home) {
  return home || process.env.HOME || "/root";
}

/**
 * Resolve the session token. Order: $KAGI_SESSION_TOKEN, then the token saved by
 * /kagi-login (kagi.json), then ~/.kagi_session_token. Returns {token, source}.
 */
export async function resolveSessionToken({ env = process.env, home, readFile } = {}) {
  const fromEnv = normalizeSessionToken(env?.KAGI_SESSION_TOKEN);
  if (fromEnv) return { token: fromEnv, source: "KAGI_SESSION_TOKEN" };
  const h = homeOf(home);
  const configText = await readTextOrNull(path.join(h, CONFIG_REL), readFile);
  if (configText) {
    try {
      const fromConfig = normalizeSessionToken(JSON.parse(configText)?.sessionToken);
      if (fromConfig) return { token: fromConfig, source: "~/.pi/kagi.json" };
    } catch {
      /* corrupt config: fall through to the token file */
    }
  }
  const fromFile = normalizeSessionToken(await readTextOrNull(path.join(h, TOKEN_FILE_REL), readFile));
  if (fromFile) return { token: fromFile, source: "~/.kagi_session_token" };
  return null;
}

function isPlainObject(v) {
  return v !== null && typeof v === "object" && !Array.isArray(v);
}

/**
 * Read kagi.json. Returns {} when missing. A file that is not a JSON object is
 * reported via `onCorrupt` and also yields {} (callers must not then overwrite it:
 * writeConfig backs it up first).
 */
export async function readConfig({ home, readFile, chmod, onCorrupt } = {}) {
  const file = path.join(homeOf(home), CONFIG_REL);
  const text = await readTextOrNull(file, readFile);
  if (text === null || text.trim() === "") return {};
  // Legacy files were written 0644 although they hold the session cookie.
  try {
    await (chmod ? chmod(file, 0o600) : fsp.chmod(file, 0o600));
  } catch {
    /* best effort */
  }
  try {
    const data = JSON.parse(text);
    if (isPlainObject(data)) return data;
  } catch {
    /* fall through */
  }
  onCorrupt?.(file);
  return {};
}

/**
 * Merge `patch` into kagi.json atomically (0600 temp file + rename).
 *
 * - `threads` and `profiles` merge by key; a null value removes the key. This keeps
 *   entries written by other sessions since the caller's snapshot.
 * - A corrupt existing file is renamed to kagi.json.corrupt-<time> instead of being
 *   silently replaced (it may still contain the token).
 * - Threads beyond MAX_THREADS are pruned, oldest `updatedAt` first.
 */
export async function writeConfig(patch, { home, fs = fsp, now = Date.now } = {}) {
  const file = path.join(homeOf(home), CONFIG_REL);
  await fs.mkdir(path.dirname(file), { recursive: true, mode: 0o700 });
  let current = {};
  let text = null;
  try {
    text = await fs.readFile(file, "utf8");
  } catch {
    text = null;
  }
  if (text !== null && text.trim() !== "") {
    let parsed;
    try {
      parsed = JSON.parse(text);
    } catch {
      parsed = undefined;
    }
    if (isPlainObject(parsed)) current = parsed;
    else await fs.rename(file, `${file}.corrupt-${now()}`);
  }
  const next = { ...current };
  for (const [key, value] of Object.entries(patch ?? {})) {
    if ((key === "threads" || key === "profiles") && isPlainObject(value)) {
      const merged = { ...(isPlainObject(current[key]) ? current[key] : {}) };
      for (const [k, v] of Object.entries(value)) {
        if (v === null) delete merged[k];
        else merged[k] = v;
      }
      next[key] = merged;
    } else if (value === null) {
      delete next[key];
    } else {
      next[key] = value;
    }
  }
  if (isPlainObject(next.threads)) {
    const entries = Object.entries(next.threads);
    if (entries.length > MAX_THREADS) {
      entries.sort((a, b) => (b[1]?.updatedAt ?? 0) - (a[1]?.updatedAt ?? 0));
      next.threads = Object.fromEntries(entries.slice(0, MAX_THREADS));
    }
  }
  const tmp = `${file}.tmp-${randomUUID()}`;
  await fs.writeFile(tmp, JSON.stringify(next, null, 2) + "\n", { mode: 0o600 });
  await fs.rename(tmp, file);
  return next;
}

/**
 * Opt-in debug log ($KAGI_DEBUG=1): ~/.pi/agent/kagi-assistant-debug.jsonl, 0600.
 * Never receives the token; callers pass metadata and truncated excerpts.
 */
export function createDebugLog({ env = process.env, home, fs: syncFs } = {}) {
  if (!env?.KAGI_DEBUG) return () => {};
  const file = path.join(homeOf(home), ".pi/agent/kagi-assistant-debug.jsonl");
  return (event, data) => {
    try {
      syncFs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
      syncFs.appendFileSync(file, JSON.stringify({ ts: new Date().toISOString(), event, ...data }) + "\n", { mode: 0o600 });
    } catch {
      /* best effort */
    }
  };
}
