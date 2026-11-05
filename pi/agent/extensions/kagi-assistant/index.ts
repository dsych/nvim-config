/**
 * Kagi Assistant as a pi model provider ("kagi/<model>").
 *
 * Kagi's models cannot call pi's tools natively. A managed Kagi profile teaches
 * them to write tool calls as plain text; this provider parses that text into pi
 * tool calls and relays the results back. See DESIGN.md for the wire facts and
 * the conversation-delivery model.
 *
 * Token: $KAGI_SESSION_TOKEN, then /kagi-login (~/.pi/kagi.json), then
 * ~/.kagi_session_token. A token or a Kagi session link is accepted.
 */
import { randomUUID } from "node:crypto";
import fs from "node:fs";
import os from "node:os";

import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import {
  type Api,
  type AssistantMessage,
  type AssistantMessageEventStream,
  createAssistantMessageEventStream,
  getCurrentSystemPrompt,
  getCurrentTools,
  type Model,
  type SimpleStreamOptions,
  type TextContent,
  type ThinkingContent,
  type ToolCall,
  type TranscriptContext,
} from "@earendil-works/pi-ai";

import { DEFAULT_BUDGET_USD, formatUsd, KagiBudget } from "./lib/budget.mjs";
import { KAGI_API_ID, KAGI_PROVIDER_ID, mapCatalog, resolveEffort } from "./lib/catalog.mjs";
import { createKagiClient, KAGI_BASE_URL, KagiApiError, waitForTurn } from "./lib/client.mjs";
import { createDebugLog, normalizeSessionToken, readConfig, resolveSessionToken, writeConfig } from "./lib/config.mjs";
import { buildProfileInstructions, coerceParameterValue, parseToolCalls, renderCorrection, VisibleTextFilter } from "./lib/protocol.mjs";
import { KagiTurnNormalizer, parseFrameData, SseDecoder } from "./lib/stream.mjs";
import { hashText, loadThreadState, planDelivery, stateAfterSend, stateSettled, stateWithTurn } from "./lib/thread.mjs";

type Notify = (message: string, level?: "info" | "warning" | "error") => void;
type Client = ReturnType<typeof createKagiClient>;

const PROFILE_INSTRUCTIONS = buildProfileInstructions();
const PROFILE_HASH = hashText(PROFILE_INSTRUCTIONS);
const MAX_CORRECTIONS = 2;
/** Kagi built-ins that answer from the web/knowledge, not from (absent) files. */
const KAGI_KNOWLEDGE_TOOLS = new Set(["search", "librarian"]);

const budget = new KagiBudget();
const modelMeta = new Map<string, { requiresSearch: boolean; thinkingLevelMap: Record<string, string | null> | null }>();
const memoryThreads = new Map<string, any>(); // sessions without an id (not persisted)
const debug = createDebugLog({ fs });
let notifyUi: Notify | undefined;
let lastBilling: any = null;
let consecutiveFreshStarts = 0;

function notify(message: string, level: "info" | "warning" | "error" = "info") {
  try {
    notifyUi?.(message, level);
  } catch {
    /* no UI (print mode) */
  }
}

function errorMessage(e: unknown): string {
  return e instanceof Error ? e.message : String(e);
}

function abortError() {
  return Object.assign(new Error("Aborted."), { name: "AbortError" });
}

/** Native call arguments may hold arrays/objects as JSON text (seen from Claude). */
function coerceArguments(tool: any, args: Record<string, unknown>) {
  const props = tool?.parameters?.properties ?? {};
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(args)) out[k] = typeof v === "string" ? coerceParameterValue(props[k], v) : v;
  return out;
}

// ---------------------------------------------------------------------------
// Persistence
// ---------------------------------------------------------------------------

async function loadThread(home: string, sessionId: string | undefined) {
  if (!sessionId) return memoryThreads.get("") ?? null;
  return loadThreadState(await readConfig({ home }), sessionId);
}

async function saveThread(home: string, sessionId: string | undefined, state: any) {
  if (!sessionId) {
    memoryThreads.set("", state);
    return;
  }
  try {
    await writeConfig({ threads: { [sessionId]: state } }, { home });
  } catch (e) {
    debug("thread_save_failed", { error: errorMessage(e) });
  }
}

/** The managed profile carrying the protocol; created or updated when instructions change. */
async function ensureProfile(client: Client, modelId: string, home: string, signal?: AbortSignal, force = false) {
  const config = await readConfig({ home });
  const cached = config.profiles?.[modelId];
  if (!force && cached?.uuid && cached.hash === PROFILE_HASH) return cached.uuid as string;
  const name = `pi-harness-${modelId}`;
  const payload = {
    name,
    llm_id: modelId,
    instructions: PROFILE_INSTRUCTIONS,
    internet_access: Boolean(modelMeta.get(modelId)?.requiresSearch),
    personalizations: false,
    lens_id: null,
    bang_trigger: null,
  };
  const list: any = await client.listProfiles({ signal });
  const profiles = Array.isArray(list) ? list : (list?.assistants ?? []);
  const existing = profiles.find((p: any) => p?.name === name);
  let uuid: string | undefined;
  if (existing) {
    uuid = existing.uuid ?? existing.id;
    const stale =
      existing.instructions !== payload.instructions ||
      existing.llm_id !== payload.llm_id ||
      Boolean(existing.internet_access) !== payload.internet_access ||
      Boolean(existing.personalizations);
    if (stale && uuid) await client.updateProfile(uuid, payload, { signal });
  } else {
    const created: any = await client.createProfile(payload, { signal });
    uuid = created?.uuid ?? created?.id;
  }
  if (!uuid) throw new Error("Kagi returned a profile without a uuid.");
  await writeConfig({ profiles: { [modelId]: { uuid, hash: PROFILE_HASH } } }, { home }).catch((e) =>
    debug("profile_save_failed", { error: errorMessage(e) }),
  );
  return uuid;
}

/** Wait for an unfinished turn (aborted turns keep running and are billed); returns its cost. */
async function settleTurn(client: Client, turnUuid: string, signal?: AbortSignal) {
  try {
    const turn: any = await waitForTurn(client, turnUuid, { signal });
    debug("turn_settled", { turnUuid, status: turn?.status, cost: turn?.cost_usd });
    return Number(turn?.cost_usd) || 0;
  } catch (e) {
    if (signal?.aborted) throw e;
    debug("turn_settle_failed", { turnUuid, error: errorMessage(e) });
    return 0;
  }
}

// ---------------------------------------------------------------------------
// Output message assembly
// ---------------------------------------------------------------------------

class MessageWriter {
  private thinking = new Map<string, number>(); // nodeId -> content index (-1 until text arrives)
  private textIndex = -1;
  private textOpen = false;

  constructor(
    private stream: AssistantMessageEventStream,
    private output: AssistantMessage,
  ) {}

  /** Thinking blocks open on their first text: some models stream empty thinking nodes. */
  thinkingStart(nodeId: string) {
    this.thinking.set(nodeId, -1);
  }

  thinkingDelta(nodeId: string, delta: string) {
    let i = this.thinking.get(nodeId);
    if (i === undefined || !delta) return;
    if (i === -1) {
      this.output.content.push({ type: "thinking", thinking: "" } as ThinkingContent);
      i = this.output.content.length - 1;
      this.thinking.set(nodeId, i);
      this.stream.push({ type: "thinking_start", contentIndex: i, partial: this.output });
    }
    (this.output.content[i] as ThinkingContent).thinking += delta;
    this.stream.push({ type: "thinking_delta", contentIndex: i, delta, partial: this.output });
  }

  thinkingEnd(nodeId: string) {
    const i = this.thinking.get(nodeId);
    if (i === undefined) return;
    this.thinking.delete(nodeId);
    if (i === -1) return;
    const block = this.output.content[i] as ThinkingContent;
    this.stream.push({ type: "thinking_end", contentIndex: i, content: block.thinking, partial: this.output });
  }

  /** Visible text. The text block opens on the first non-whitespace text. */
  text(delta: string) {
    if (!delta) return;
    if (this.textIndex === -1) {
      delta = delta.replace(/^\s+/, "");
      if (!delta) return;
      this.output.content.push({ type: "text", text: "" } as TextContent);
      this.textIndex = this.output.content.length - 1;
      this.textOpen = true;
      this.stream.push({ type: "text_start", contentIndex: this.textIndex, partial: this.output });
    }
    if (!this.textOpen) return;
    (this.output.content[this.textIndex] as TextContent).text += delta;
    this.stream.push({ type: "text_delta", contentIndex: this.textIndex, delta, partial: this.output });
  }

  textEnd() {
    if (!this.textOpen) return;
    this.textOpen = false;
    const block = this.output.content[this.textIndex] as TextContent;
    block.text = block.text.trimEnd();
    this.stream.push({ type: "text_end", contentIndex: this.textIndex, content: block.text, partial: this.output });
  }

  closeAll() {
    for (const nodeId of [...this.thinking.keys()]) this.thinkingEnd(nodeId);
    this.textEnd();
  }

  toolCall(name: string, args: Record<string, unknown>, native = false) {
    const id = `kagi_${native ? "n" : "t"}_${randomUUID().replaceAll("-", "").slice(0, 16)}`;
    const part: ToolCall = { type: "toolCall", id, name, arguments: args as any };
    this.output.content.push(part);
    const i = this.output.content.length - 1;
    this.stream.push({ type: "toolcall_start", contentIndex: i, partial: this.output });
    this.stream.push({ type: "toolcall_end", contentIndex: i, toolCall: part, partial: this.output });
  }
}

// ---------------------------------------------------------------------------
// Turn streaming
// ---------------------------------------------------------------------------

interface Started {
  conversationUuid: string;
  branchUuid: string;
  turnUuid: string;
}

async function sendMessage(
  client: Client,
  model: Model<Api>,
  options: SimpleStreamOptions,
  { content, profileUuid, effort, branchUuid }: { content: string; profileUuid: string; effort?: string; branchUuid?: string },
): Promise<Started> {
  let body: any = {
    model: model.id,
    content,
    profile_uuid: profileUuid,
    enable_search: Boolean(modelMeta.get(model.id)?.requiresSearch),
    personalization: false,
  };
  if (effort) body.reasoning_effort = effort;
  if (options.onPayload) {
    const replaced = await options.onPayload(body, model);
    if (replaced !== undefined) body = replaced;
  }
  const onResponse = options.onResponse
    ? (res: Response) => options.onResponse!({ status: res.status, headers: Object.fromEntries(res.headers) }, model)
    : undefined;
  const r: any = branchUuid
    ? await client.respond(branchUuid, body, { signal: options.signal, onResponse })
    : await client.startConversation(body, { signal: options.signal, onResponse });
  const started = {
    conversationUuid: r?.conversation_uuid ?? r?.conversation?.uuid,
    branchUuid: r?.branch_uuid ?? r?.branch?.uuid ?? branchUuid,
    turnUuid: r?.assistant_turn_uuid,
  };
  if (!started.conversationUuid || !started.branchUuid || !started.turnUuid) {
    throw new Error(`Kagi returned an unexpected turn response: ${JSON.stringify(r).slice(0, 200)}`);
  }
  return started;
}

/** Read one turn's SSE stream; `onEvent` receives normalised content events. */
async function readTurn(
  client: Client,
  turnUuid: string,
  model: Model<Api>,
  options: SimpleStreamOptions,
  onEvent: (ev: any) => void,
): Promise<KagiTurnNormalizer> {
  const signal = options.signal;
  const onResponse = options.onResponse
    ? (res: Response) => options.onResponse!({ status: res.status, headers: Object.fromEntries(res.headers) }, model)
    : undefined;
  const res: Response = await client.streamTurn(turnUuid, { signal, onResponse });
  const reader = res.body!.getReader();
  const decoder = new SseDecoder();
  const norm = new KagiTurnNormalizer();
  const onAbort = () => void reader.cancel().catch(() => {});
  signal?.addEventListener("abort", onAbort, { once: true });
  const handle = async (frames: any[]) => {
    for (const frame of frames) {
      const data = parseFrameData(frame);
      if (!data) continue;
      if (options.onProviderStreamEvent) await options.onProviderStreamEvent(data, model);
      for (const ev of norm.feed(data)) onEvent(ev);
    }
  };
  try {
    while (!norm.isFinal && !norm.failed) {
      let chunk: ReadableStreamReadResult<Uint8Array>;
      try {
        chunk = await reader.read();
      } catch (e) {
        if (signal?.aborted) break;
        throw e;
      }
      if (chunk.done) break;
      await handle(decoder.push(chunk.value));
    }
    if (!signal?.aborted) await handle(decoder.end());
  } finally {
    signal?.removeEventListener("abort", onAbort);
    await reader.cancel().catch(() => {});
  }
  for (const ev of norm.closeAll()) onEvent(ev);
  if (norm.unknownNodes.length) debug("unknown_nodes", { turnUuid, nodes: norm.unknownNodes });
  if (norm.billing) lastBilling = norm.billing;
  return norm;
}

function zeroUsage() {
  return {
    input: 0,
    output: 0,
    cacheRead: 0,
    cacheWrite: 0,
    totalTokens: 0,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
  };
}

function addUsage(output: AssistantMessage, u: any) {
  output.usage.input += u.input;
  output.usage.output += u.output;
  output.usage.cacheRead += u.cacheRead;
  output.usage.cacheWrite += u.cacheWrite;
  output.usage.totalTokens += u.totalTokens;
  addCost(output, u.costUsd);
}

function addCost(output: AssistantMessage, costUsd: number) {
  if (!costUsd) return;
  output.usage.cost.total += costUsd;
  for (const m of budget.record(costUsd)) notify(m.text, m.level as any);
}

async function runTurn(model: Model<Api>, context: TranscriptContext, options: SimpleStreamOptions, stream: AssistantMessageEventStream, output: AssistantMessage) {
  const signal = options.signal;
  const home = os.homedir();
  const writer = new MessageWriter(stream, output);
  let started = false;
  const begin = () => {
    if (!started) {
      started = true;
      stream.push({ type: "start", partial: output });
    }
  };
  try {
    if (signal?.aborted) throw abortError();
    if (budget.gate() === "blocked") {
      throw new Error(
        `Kagi Assistant conversation cap reached (${formatUsd(budget.spentUsd)} of ${formatUsd(budget.limit)}). Raise it with /kagi-budget <usd>.`,
      );
    }
    const token = await resolveSessionToken({ env: { ...process.env, ...(options.env ?? {}) }, home });
    if (!token) {
      throw new Error("No Kagi session token. Run /kagi-login, or save a token or session link in ~/.kagi_session_token.");
    }
    const client = createKagiClient({ token: token.token, fetch: options.fetch, headers: options.headers as any });
    const systemPrompt = getCurrentSystemPrompt(context.messages);
    const tools = getCurrentTools(context.messages);
    const sessionId = options.sessionId;
    const effort = resolveEffort(modelMeta.get(model.id)?.thinkingLevelMap ?? (model as any).thinkingLevelMap ?? null, options.reasoning);

    let state = await loadThread(home, sessionId);
    if (state?.lastTurn && !state.lastTurn.settled) {
      addCost(output, await settleTurn(client, state.lastTurn.uuid, signal));
      state = stateSettled(state);
      await saveThread(home, sessionId, state);
    }

    let plan: any = planDelivery({ messages: context.messages, systemPrompt, tools, state });
    if (plan.mode === "error") throw new Error(plan.error);
    let profileUuid = await ensureProfile(client, model.id, home, signal);

    // Send, recovering once each from a deleted profile, an expired conversation
    // and a still-running previous turn.
    let turn: Started | undefined;
    const recovered = new Set<string>();
    for (;;) {
      try {
        turn = await sendMessage(client, model, options, {
          content: plan.content,
          profileUuid,
          effort,
          branchUuid: plan.mode === "respond" ? state.branchUuid : undefined,
        });
        break;
      } catch (e) {
        if (!(e instanceof KagiApiError)) throw e;
        if (e.isProfileMissing && !recovered.has("profile")) {
          recovered.add("profile");
          profileUuid = await ensureProfile(client, model.id, home, signal, true);
        } else if (plan.mode === "respond" && e.isBranchMissing && !recovered.has("branch")) {
          recovered.add("branch");
          state = null;
          plan = { ...planDelivery({ messages: context.messages, systemPrompt, tools, state: null }), reason: "expired" };
        } else if (e.isBusy && !recovered.has("busy")) {
          // The previous turn is still finishing; its cost was counted when settled.
          recovered.add("busy");
          if (state?.lastTurn) await settleTurn(client, state.lastTurn.uuid, signal);
        } else {
          throw e;
        }
      }
    }
    if (plan.reason === "history-changed" || plan.reason === "expired") {
      consecutiveFreshStarts++;
      notify(
        plan.reason === "expired"
          ? "Kagi Assistant: the Kagi conversation expired; started a new one with the full transcript."
          : "Kagi Assistant: the history changed (edit, rewind or compaction); started a new Kagi conversation with the full transcript.",
        consecutiveFreshStarts >= 3 ? "warning" : "info",
      );
    } else if (plan.mode === "respond") {
      consecutiveFreshStarts = 0;
    }
    debug("sent", { mode: plan.mode, reason: plan.reason, chars: plan.content.length, model: model.id, effort });
    state = stateAfterSend(state, plan, turn);
    await saveThread(home, sessionId, state);
    output.responseId = turn.turnUuid;
    begin();

    const filter = new VisibleTextFilter();
    const declared = new Set(tools.map((t: any) => t.name));
    // Per-turn tracking of native function calls (see DESIGN.md "Native calls").
    const freshNative = () => ({
      declared: [] as { name: string; arguments: Record<string, unknown> }[],
      declaredStarted: false,
      builtin: new Set<string>(),
      fileTools: false,
      step: null as number | null,
      cancelled: false,
    });
    let native = freshNative();
    let textNodes = 0;
    let suppress = false; // after a native declared call: the rest of the turn is discarded
    let holdText = false; // after a built-in file tool: text waits until the outcome is known
    let written = ""; // text shown so far, across correction turns
    const show = (text: string) => {
      if (!text) return;
      writer.text(text);
      written += text;
    };
    const cancelTurn = () => {
      if (native.cancelled) return;
      native.cancelled = true;
      void client.cancelTurn(turn!.turnUuid).catch((e: unknown) => debug("cancel_failed", { error: errorMessage(e) }));
    };
    const onEvent = (ev: any) => {
      // A declared tool called natively in step N: the server answers "unknown
      // tool" and the model carries on. Stop the turn when it moves on.
      if (native.step !== null && (ev.type === "text_start" || ev.type === "thinking_start") && (ev.step ?? 0) > native.step) {
        suppress = true;
        cancelTurn();
      }
      if (ev.type === "native_call_start") {
        // Built-in Kagi tools run on Kagi's server and cannot see the user's
        // computer. They are not interrupted (some models explore with them and
        // then write a proper call in the same turn), but text written after a
        // built-in file tool is held back: it usually reports files as missing.
        if (declared.has(ev.name)) native.declaredStarted = true;
        else if (ev.name) {
          native.builtin.add(ev.name);
          if (!KAGI_KNOWLEDGE_TOOLS.has(ev.name)) {
            native.fileTools = true;
            holdText = true;
          }
        }
        return;
      }
      if (ev.type === "native_call") {
        if (declared.has(ev.name)) {
          const tool: any = tools.find((t: any) => t.name === ev.name);
          native.declared.push({ name: ev.name, arguments: coerceArguments(tool, ev.arguments ?? {}) });
          native.step ??= ev.step ?? 0;
        }
        return;
      }
      if (suppress) {
        if (ev.type === "thinking_end") writer.thinkingEnd(ev.nodeId);
        return;
      }
      if (ev.type === "thinking_start") writer.thinkingStart(ev.nodeId);
      else if (ev.type === "thinking_delta") writer.thinkingDelta(ev.nodeId, ev.delta);
      else if (ev.type === "thinking_end") writer.thinkingEnd(ev.nodeId);
      else if (ev.type === "text_start") {
        if (textNodes++ > 0 && filter.full.trim()) {
          const out = filter.push("\n\n");
          if (!holdText) show(out);
        }
      } else if (ev.type === "text_delta") {
        const out = filter.push(ev.delta);
        if (!holdText) show(out);
      }
    };

    for (let corrections = 0; ; corrections++) {
      let norm: KagiTurnNormalizer;
      try {
        norm = await readTurn(client, turn.turnUuid, model, options, onEvent);
      } catch (e) {
        if (signal?.aborted) cancelTurn();
        throw e;
      }
      if (norm.usage) addUsage(output, norm.usage);
      // A turn's cost is known once usage arrived. Otherwise (cut stream, failure
      // without usage) the next call collects it from the turn record.
      const cancelledByUs = native.cancelled && norm.failed?.type === "turn.cancelled";
      if (norm.usage || cancelledByUs) {
        state = stateSettled(state);
        await saveThread(home, sessionId, state);
      }
      if (signal?.aborted) {
        // Stop the server-side turn: an uncancelled turn runs to the end and is billed.
        cancelTurn();
        throw abortError();
      }
      if (norm.failed && !cancelledByUs) throw new Error(norm.failed.message);
      if (!norm.completed && !cancelledByUs) throw new Error("Kagi Assistant stream ended before the turn completed.");

      const parsed = parseToolCalls(filter.full, tools);
      for (const w of parsed.warnings) debug("parse_warning", { warning: w });
      // Calls written as text and calls made natively, without duplicates.
      const seen = new Set<string>();
      const calls = [
        ...native.declared.map((c) => ({ ...c, native: true })),
        ...parsed.calls.map((c: any) => ({ ...c, native: false })),
      ].filter((c) => {
        const key = `${c.name}\u0000${JSON.stringify(c.arguments)}`;
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      });
      const problem =
        parsed.problem ??
        (native.fileTools
          ? `you used built-in Kagi tools (${[...native.builtin].join(", ")}). They run on a remote server without access to the user's computer`
          : null);
      if (!calls.length && problem && corrections < MAX_CORRECTIONS) {
        // A tool call was intended but nothing runnable came out: ask for a
        // corrected block in the same conversation and stream that instead.
        debug("correction", { problem });
        if (budget.gate() === "blocked") throw new Error("Kagi Assistant conversation cap reached during a tool-call correction.");
        const previousTurn = turn.turnUuid;
        const correction = { content: renderCorrection(problem, tools), profileUuid, effort, branchUuid: state.branchUuid };
        try {
          turn = await sendMessage(client, model, options, correction);
        } catch (e) {
          if (!(e instanceof KagiApiError && e.isBusy)) throw e;
          await settleTurn(client, previousTurn, signal); // still finishing; wait, then retry once
          turn = await sendMessage(client, model, options, correction);
        }
        state = stateWithTurn(state, turn.turnUuid);
        await saveThread(home, sessionId, state);
        output.responseId = turn.turnUuid;
        filter.resetTo(written); // withheld text of the failed attempt is dropped
        textNodes = written.trim() ? 1 : 0;
        native = freshNative();
        suppress = false;
        holdText = false;
        continue;
      }
      if (!calls.length && problem) notify(`Kagi Assistant: no tool call could be run (${problem}).`, "warning");
      // Text held back after a sandbox file tool is dropped when only native calls ran.
      const finalText = parsed.calls.length ? parsed.visibleText : holdText && calls.length ? written : filter.full;
      if (finalText.startsWith(written)) show(finalText.slice(written.length));
      writer.textEnd();
      for (const call of calls) writer.toolCall(call.name, call.arguments, call.native);
      writer.closeAll();
      output.stopReason = calls.length ? "toolUse" : "stop";
      stream.push({ type: "done", reason: output.stopReason as any, message: output });
      stream.end();
      return;
    }
  } catch (e) {
    const aborted = Boolean(signal?.aborted) || (e as any)?.name === "AbortError";
    writer.closeAll();
    output.stopReason = aborted ? "aborted" : "error";
    output.errorMessage = aborted ? "Aborted." : errorMessage(e);
    debug("turn_error", { aborted, error: output.errorMessage });
    begin();
    stream.push({ type: "error", reason: output.stopReason as any, error: output });
    stream.end();
  }
}

function streamKagi(model: Model<Api>, context: TranscriptContext, options?: SimpleStreamOptions): AssistantMessageEventStream {
  const stream = createAssistantMessageEventStream();
  const output: AssistantMessage = {
    role: "assistant",
    content: [],
    api: model.api,
    provider: model.provider,
    model: model.id,
    usage: zeroUsage(),
    stopReason: "pending",
    timestamp: Date.now(),
  };
  void runTurn(model, context, options ?? {}, stream, output);
  return stream;
}

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

async function fetchCatalog(token: string) {
  const init: any = await createKagiClient({ token }).init({ timeoutMs: 10_000 });
  return mapCatalog(init);
}

export default async function kagiAssistant(pi: ExtensionAPI) {
  const home = os.homedir();
  const startupNotes: string[] = [];
  budget.setLimit((await readConfig({ home })).budgetUsd ?? DEFAULT_BUDGET_USD);

  const token = await resolveSessionToken({ home });
  let models: any[] = [];
  if (token) {
    try {
      const catalog = await fetchCatalog(token.token);
      models = catalog.models;
      for (const [id, meta] of catalog.meta) modelMeta.set(id, meta);
      if (!models.length) startupNotes.push("Kagi Assistant: the catalog returned no models this account can use.");
    } catch (e) {
      startupNotes.push(
        `Kagi Assistant: model catalog unavailable (${errorMessage(e)}). Token from ${token.source}; run /kagi-login if it expired.`,
      );
    }
  } else {
    startupNotes.push("Kagi Assistant: no session token. Run /kagi-login, or save a token or session link in ~/.kagi_session_token.");
  }

  pi.registerProvider(KAGI_PROVIDER_ID, {
    name: "Kagi Assistant",
    baseUrl: KAGI_BASE_URL,
    // Satisfies pi's auth gate; the real cookie is resolved per request.
    apiKey: "kagi-session-cookie",
    api: KAGI_API_ID,
    models,
    streamSimple: streamKagi,
  } as any);

  pi.on("session_start", async (_event: any, ctx: any) => {
    notifyUi = ctx?.hasUI === false ? undefined : (m, l) => ctx.ui.notify(m, l);
    for (const note of startupNotes.splice(0)) notify(note, "warning");
    // Resume: seed the cap with what this session already spent (real dollars).
    let spent = 0;
    try {
      for (const entry of ctx.sessionManager.getEntries()) {
        const msg = entry?.type === "message" ? entry.message : null;
        if (msg?.role === "assistant" && msg.provider === KAGI_PROVIDER_ID) spent += msg.usage?.cost?.total ?? 0;
      }
    } catch {
      /* no entries */
    }
    budget.seed(spent);
    consecutiveFreshStarts = 0;
  });

  pi.registerCommand("kagi-budget", {
    description: "Show or set the per-conversation Kagi spend cap in USD (default $3): /kagi-budget [usd]",
    handler: async (args: string, ctx: ExtensionCommandContext) => {
      const arg = (args ?? "").trim();
      if (!arg) {
        const plan = lastBilling?.usage?.included_cost_limit_usd
          ? ` Kagi plan: ${formatUsd(lastBilling.usage.included_cost_usd)} of ${formatUsd(lastBilling.usage.included_cost_limit_usd)} included usage.`
          : "";
        ctx.ui.notify(`Kagi Assistant: ${formatUsd(budget.spentUsd)} of ${formatUsd(budget.limit)} spent in this conversation.${plan}`, "info");
        return;
      }
      const value = Number(arg.replace(/^\$/, ""));
      if (!Number.isFinite(value) || value <= 0) {
        ctx.ui.notify("Kagi Assistant: expected a positive amount, e.g. /kagi-budget 5", "error");
        return;
      }
      budget.setLimit(value);
      await writeConfig({ budgetUsd: value }, { home });
      ctx.ui.notify(`Kagi Assistant: conversation cap set to ${formatUsd(value)}.`, "info");
    },
  });

  pi.registerCommand("kagi-new-thread", {
    description: "Start a new Kagi conversation on the next message (the full transcript is resent).",
    handler: async (_args: string, ctx: ExtensionCommandContext) => {
      const sessionId = ctx.sessionManager.getSessionId();
      if (sessionId) await writeConfig({ threads: { [sessionId]: null } }, { home });
      else memoryThreads.delete("");
      ctx.ui.notify("Kagi Assistant: the next message starts a new Kagi conversation.", "info");
    },
  });

  pi.registerCommand("kagi-login", {
    description: "Save a Kagi session token or session link to ~/.pi/kagi.json, then reload.",
    handler: async (_args: string, ctx: ExtensionCommandContext) => {
      const input = await ctx.ui.input("Kagi session token or session link:", "https://kagi.com/search?token=...");
      const tok = normalizeSessionToken(input);
      if (!tok) {
        ctx.ui.notify("Kagi Assistant: no token entered.", "warning");
        return;
      }
      try {
        await createKagiClient({ token: tok }).init({ timeoutMs: 10_000 });
      } catch (e) {
        ctx.ui.notify(`Kagi Assistant: token rejected (${errorMessage(e)}). Not saved.`, "error");
        return;
      }
      await writeConfig({ sessionToken: tok }, { home });
      const active = await resolveSessionToken({ home });
      if (active?.token !== tok) {
        ctx.ui.notify(`Kagi Assistant: token saved, but ${active?.source} takes precedence.`, "warning");
      } else {
        ctx.ui.notify("Kagi Assistant: token saved. Reloading...", "info");
      }
      await ctx.reload();
    },
  });
}
