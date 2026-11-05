/**
 * Minimal Kagi Assistant HTTP client (fetch injectable for tests). No pi imports.
 */
export const KAGI_BASE_URL = "https://assistant.kagi.com";
export const USER_AGENT = "pi-kagi-assistant/0.2 (pi-coding-agent extension)";
export const REQUEST_TIMEOUT_MS = 30_000;

export class KagiApiError extends Error {
  constructor({ surface, status, code, message, requestId, path }) {
    const detail = [code, message].filter(Boolean).join(": ");
    super(`Kagi ${surface} failed: HTTP ${status}${detail ? ` ${detail}` : ""}`);
    this.name = "KagiApiError";
    this.surface = surface;
    this.status = status;
    this.code = code;
    this.kagiMessage = message;
    this.requestId = requestId;
    this.path = path;
  }
  get isAuth() {
    return this.status === 401 || (this.status === 403 && this.code !== "forbidden");
  }
  get isNotFound() {
    return this.status === 404;
  }
  get isProfileMissing() {
    return this.status === 404 && /custom assistant/i.test(this.kagiMessage ?? "");
  }
  get isBranchMissing() {
    return this.status === 404 && /branch|conversation/i.test(this.kagiMessage ?? "");
  }
  get isBusy() {
    return this.status === 409;
  }
}

function redact(text, token) {
  const s = String(text ?? "");
  return token ? s.split(token).join("[redacted]") : s;
}

/** Parse Kagi's `{"error": {code, message, request_id}}` body (or HTML / text). */
export function parseErrorBody(text) {
  const s = String(text ?? "");
  try {
    const j = JSON.parse(s);
    const e = j?.error;
    if (e && typeof e === "object") return { code: e.code, message: e.message, requestId: e.request_id };
    if (typeof e === "string") return { message: e };
    if (typeof j?.detail === "string") return { message: j.detail };
  } catch {
    /* not JSON */
  }
  if (/<html|<!doctype/i.test(s)) return { message: "HTML response (signed out or expired session?)" };
  return { message: s.replace(/\s+/g, " ").trim().slice(0, 200) || undefined };
}

/** Combine an optional caller signal with a timeout. */
function withTimeout(signal, ms) {
  const timeout = AbortSignal.timeout(ms);
  return signal ? AbortSignal.any([signal, timeout]) : timeout;
}

/**
 * @param {object} opts
 * @param {string} opts.token
 * @param {typeof fetch} [opts.fetch]
 * @param {string} [opts.baseUrl]
 * @param {Record<string,string|null>} [opts.headers] caller headers (null removes a default)
 */
export function createKagiClient({ token, fetch: fetchImpl = globalThis.fetch, baseUrl = KAGI_BASE_URL, headers: extra } = {}) {
  const baseHeaders = (accept, json) => {
    const h = { Cookie: `kagi_session=${token}`, "User-Agent": USER_AGENT, Accept: accept };
    if (json) h["Content-Type"] = "application/json";
    for (const [k, v] of Object.entries(extra ?? {})) {
      const existing = Object.keys(h).find((key) => key.toLowerCase() === k.toLowerCase());
      if (existing) delete h[existing];
      if (v !== null && v !== undefined) h[k] = v;
    }
    return h;
  };

  /**
   * Send one request. Returns the Response for streams, parsed JSON otherwise.
   * `onResponse(response)` runs after headers arrive and before the body is read.
   */
  async function request(surface, method, path, { body, signal, stream = false, onResponse, timeoutMs = REQUEST_TIMEOUT_MS } = {}) {
    const res = await fetchImpl(baseUrl + path, {
      method,
      headers: baseHeaders(stream ? "text/event-stream" : "application/json", body !== undefined),
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: stream ? signal : withTimeout(signal, timeoutMs),
    });
    if (onResponse) await onResponse(res);
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      const parsed = parseErrorBody(redact(text, token));
      throw new KagiApiError({ surface, status: res.status, path, ...parsed });
    }
    if (stream) {
      if (!res.body) throw new KagiApiError({ surface, status: res.status, path, message: "empty stream body" });
      return res;
    }
    const text = await res.text();
    try {
      return text ? JSON.parse(text) : {};
    } catch {
      throw new KagiApiError({ surface, status: res.status, path, ...parseErrorBody(redact(text, token)) });
    }
  }

  return {
    request,
    init: (o) => request("catalog", "GET", "/api/init", o),
    listProfiles: (o) => request("profile list", "GET", "/api/assistants", o),
    createProfile: (payload, o) => request("profile create", "POST", "/api/assistants", { ...o, body: payload }),
    updateProfile: (uuid, payload, o) =>
      request("profile update", "PATCH", `/api/assistants/${encodeURIComponent(uuid)}`, { ...o, body: payload }),
    startConversation: (payload, o) => request("conversation start", "POST", "/api/v2/conversations", { ...o, body: payload }),
    respond: (branchUuid, payload, o) =>
      request("conversation respond", "POST", `/api/v2/branches/${encodeURIComponent(branchUuid)}/respond`, { ...o, body: payload }),
    getTurn: (turnUuid, o) => request("turn status", "GET", `/api/v2/turns/${encodeURIComponent(turnUuid)}`, o),
    // Stops a running turn (verified live: 204, then turn.cancelled on the stream).
    cancelTurn: (turnUuid, o) =>
      request("turn cancel", "POST", `/api/v2/turns/${encodeURIComponent(turnUuid)}/cancel`, { timeoutMs: 10_000, ...o, body: {} }),
    streamTurn: (turnUuid, o) =>
      request("turn stream", "GET", `/api/v2/turns/${encodeURIComponent(turnUuid)}/stream`, { ...o, stream: true }),
  };
}

/** Sleep that rejects with an AbortError when `signal` fires. */
export function sleep(ms, signal) {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) return reject(signal.reason ?? new DOMException("Aborted", "AbortError"));
    const t = setTimeout(() => {
      signal?.removeEventListener("abort", onAbort);
      resolve();
    }, ms);
    const onAbort = () => {
      clearTimeout(t);
      reject(signal.reason ?? new DOMException("Aborted", "AbortError"));
    };
    signal?.addEventListener("abort", onAbort, { once: true });
  });
}

const TERMINAL_TURN_STATUSES = new Set(["completed", "failed", "cancelled", "canceled", "error", "stopped"]);

/**
 * Wait until a turn is no longer running (aborted turns keep running server-side).
 * Returns the final turn record ({status, cost_usd, ...}) or the last one seen.
 */
export async function waitForTurn(client, turnUuid, { signal, timeoutMs = 120_000, intervalMs = 1000 } = {}) {
  const deadline = Date.now() + timeoutMs;
  let turn = await client.getTurn(turnUuid, { signal });
  while (!TERMINAL_TURN_STATUSES.has(String(turn?.status ?? "")) && Date.now() < deadline) {
    await sleep(intervalMs, signal);
    turn = await client.getTurn(turnUuid, { signal });
  }
  return turn;
}
