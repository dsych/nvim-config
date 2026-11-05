/**
 * What the Kagi thread has received, and what to send next. No pi imports.
 *
 * pi sends the whole context on every call; a Kagi conversation is stateful.
 * Per pi session we store the number and hash of the conversation messages the
 * thread has received, plus hashes of the system prompt and tools last sent.
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
  const conv = conversationMessages(messages);
  let lastUser = -1;
  for (let i = conv.length - 1; i >= 0; i--) {
    if (conv[i].role === "user") {
      lastUser = i;
      break;
    }
  }
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
    content: renderFresh({ systemPrompt, tools, history: conv.slice(0, lastUser), pending: conv.slice(lastUser) }),
    ...common,
  });
  if (!state) return fresh("new");
  if (state.deliveredCount > conv.length || hashMessages(conv.slice(0, state.deliveredCount)) !== state.deliveredHash) {
    return fresh("history-changed");
  }
  const own = new Set(state.turns ?? []);
  const pending = conv
    .slice(state.deliveredCount)
    .filter((m) => !(m.role === "assistant" && m.responseId && own.has(m.responseId)))
    .filter((m) => m.role !== "assistant" || hasRenderableContent(m));
  const systemChanged = common.systemHash !== state.systemHash;
  const toolsChanged = common.toolsHash !== state.toolsHash;
  if (!pending.length && !systemChanged && !toolsChanged) {
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
