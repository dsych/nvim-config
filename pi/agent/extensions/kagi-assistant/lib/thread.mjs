/**
 * What the Kagi thread has received, and what to send next. No pi imports.
 *
 * pi sends the whole context on every call; a Kagi conversation is stateful.
 * Per pi session we store the number and hash of the transcript messages the
 * thread has received, plus hashes of the system prompt and tools last sent.
 * Request-local messages added by other extensions are relayed but not counted.
 */
import { createHash } from "node:crypto";
import { CONTINUE_MESSAGE, messageText, renderDelta, renderFresh } from "./protocol.mjs";

export const THREAD_STATE_VERSION = 2;
const MAX_TURNS = 20;

export function hashText(text) {
  return createHash("sha256").update(String(text ?? "")).digest("hex");
}

/** Stable text of a message for prefix comparison (ignores timestamps, usage, thinking). */
export function canonicalMessage(m) {
  if (m.role === "user") return `u\n${messageText(m)}`;
  if (m.role === "toolResult") return `r\n${m.toolName ?? ""}\n${m.isError ? 1 : 0}\n${messageText(m)}`;
  const parts = [`a\n${m.provider ?? ""}\n${m.responseId ?? ""}`];
  for (const b of m.content ?? []) {
    if (b.type === "text") parts.push(`t:${b.text}`);
    else if (b.type === "toolCall") parts.push(`c:${b.name}:${JSON.stringify(b.arguments ?? {})}`);
  }
  return parts.join("\n");
}

export function hashMessages(messages) {
  const h = createHash("sha256");
  for (const m of messages) h.update(canonicalMessage(m)).update("\u0000");
  return h.digest("hex");
}

export function hashTools(tools) {
  return hashText(JSON.stringify((tools ?? []).map((t) => [t.name, t.description, t.parameters])));
}

/** User, assistant and tool-result messages (system messages carry prompt/tools). */
export function conversationMessages(messages) {
  return (messages ?? []).filter((m) => m.role === "user" || m.role === "assistant" || m.role === "toolResult");
}

/**
 * A user message that an extension's `context` hook added to this request only
 * (context-mode appends one to the first request of every run). pi gives every
 * transcript message a timestamp; such additions have none, and the next request
 * no longer contains them (verified on pi 1.0.3 and 1.5.2).
 */
export function isRequestLocal(m) {
  return m?.role === "user" && !Number.isFinite(m.timestamp);
}

function findLastIndex(list, predicate) {
  for (let i = list.length - 1; i >= 0; i--) if (predicate(list[i])) return i;
  return -1;
}

/** Index in `all` just after its `count`-th transcript (not request-local) message. */
function indexAfterTranscript(all, count) {
  if (count <= 0) return 0;
  let seen = 0;
  for (let i = 0; i < all.length; i++) {
    if (!isRequestLocal(all[i]) && ++seen === count) return i + 1;
  }
  return all.length;
}

function hasRenderableContent(m) {
  return (m.content ?? []).some((b) => (b.type === "text" && b.text?.trim()) || b.type === "toolCall");
}

/** Validated thread state for a session, or null. */
export function loadThreadState(config, sessionId) {
  const t = config?.threads?.[sessionId];
  if (!t || t.v !== THREAD_STATE_VERSION) return null;
  const ok =
    typeof t.conversationUuid === "string" &&
    t.conversationUuid &&
    typeof t.branchUuid === "string" &&
    t.branchUuid &&
    Number.isInteger(t.deliveredCount) &&
    t.deliveredCount >= 0 &&
    typeof t.deliveredHash === "string";
  return ok ? t : null;
}

/**
 * Decide what to send for this pi call.
 *
 * Returns {mode: "error", error} or
 * {mode: "start"|"respond", reason, content, deliveredCount, deliveredHash, systemHash, toolsHash}.
 */
export function planDelivery({ messages, systemPrompt, tools, state }) {
  // `all` is what this request shows the model; `conv` drops request-local
  // additions and is what the delivered prefix (count and hash) is measured on.
  const all = conversationMessages(messages);
  const conv = all.filter((m) => !isRequestLocal(m));
  // The new part starts at the last user message of the transcript, so a
  // request-local addition after it does not push the prompt into the history.
  let lastUser = findLastIndex(all, (m) => m.role === "user" && !isRequestLocal(m));
  if (lastUser === -1) lastUser = findLastIndex(all, (m) => m.role === "user");
  if (lastUser === -1) return { mode: "error", error: "No user message in the context; nothing to send to Kagi Assistant." };
  const common = {
    deliveredCount: conv.length,
    deliveredHash: hashMessages(conv),
    systemHash: hashText(systemPrompt),
    toolsHash: hashTools(tools),
  };
  const fresh = (reason) => ({
    mode: "start",
    reason,
    content: renderFresh({ systemPrompt, tools, history: all.slice(0, lastUser), pending: all.slice(lastUser) }),
    ...common,
  });
  if (!state) return fresh("new");
  if (state.deliveredCount > conv.length || hashMessages(conv.slice(0, state.deliveredCount)) !== state.deliveredHash) {
    return fresh("history-changed");
  }
  const own = new Set(state.turns ?? []);
  // Request-local additions inside the delivered part are not resent.
  const pending = all
    .slice(indexAfterTranscript(all, state.deliveredCount))
    .filter((m) => !(m.role === "assistant" && m.responseId && own.has(m.responseId)))
    .filter((m) => m.role !== "assistant" || hasRenderableContent(m));
  const systemChanged = common.systemHash !== state.systemHash;
  const toolsChanged = common.toolsHash !== state.toolsHash;
  // Nothing new in the transcript (request-local additions do not count): a retry.
  if (!pending.some((m) => !isRequestLocal(m)) && !systemChanged && !toolsChanged) {
    return { mode: "respond", reason: "retry", content: CONTINUE_MESSAGE, ...common };
  }
  return {
    mode: "respond",
    reason: "delta",
    content: renderDelta({
      pending,
      systemPrompt: systemChanged ? systemPrompt : undefined,
      tools: toolsChanged ? tools : undefined,
    }),
    ...common,
  };
}

/** State after Kagi accepted a message (the thread now contains it). */
export function stateAfterSend(prev, plan, started, now = Date.now()) {
  const sameConversation = prev && prev.conversationUuid === started.conversationUuid;
  const turns = [...(sameConversation ? prev.turns ?? [] : []), started.turnUuid].slice(-MAX_TURNS);
  return {
    v: THREAD_STATE_VERSION,
    conversationUuid: started.conversationUuid,
    branchUuid: started.branchUuid,
    deliveredCount: plan.deliveredCount,
    deliveredHash: plan.deliveredHash,
    systemHash: plan.systemHash,
    toolsHash: plan.toolsHash,
    turns,
    lastTurn: { uuid: started.turnUuid, settled: false },
    updatedAt: now,
  };
}

/** Add a follow-up turn in the same conversation (correction retries). */
export function stateWithTurn(state, turnUuid, now = Date.now()) {
  return {
    ...state,
    turns: [...(state.turns ?? []), turnUuid].slice(-MAX_TURNS),
    lastTurn: { uuid: turnUuid, settled: false },
    updatedAt: now,
  };
}

/** Mark the last turn settled (its cost is known and counted). */
export function stateSettled(state, now = Date.now()) {
  return { ...state, lastTurn: state.lastTurn ? { ...state.lastTurn, settled: true } : null, updatedAt: now };
}
