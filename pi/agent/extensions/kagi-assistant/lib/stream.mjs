/**
 * Kagi turn stream: SSE framing, event normalisation and usage mapping.
 * No pi imports. Wire format verified live (see DESIGN.md).
 */

/** Parse one SSE frame (lines without the blank separator) into {id?, data} or null. */
export function parseSseFrame(raw) {
  let id;
  const data = [];
  for (const line of String(raw).split("\n")) {
    if (line.startsWith("data:")) data.push(line.slice(5).replace(/^ /, ""));
    else if (line.startsWith("id:")) id = line.slice(3).trim();
  }
  return data.length ? { id, data: data.join("\n") } : null;
}

/** Incremental SSE framing over decoded text. */
export class SseFrameParser {
  constructor() {
    this.buffer = "";
  }
  feed(text) {
    const frames = [];
    if (!text) return frames;
    this.buffer += String(text).replace(/\r\n?/g, "\n");
    let i;
    while ((i = this.buffer.indexOf("\n\n")) !== -1) {
      const frame = parseSseFrame(this.buffer.slice(0, i));
      this.buffer = this.buffer.slice(i + 2);
      if (frame) frames.push(frame);
    }
    return frames;
  }
  flush() {
    const frame = parseSseFrame(this.buffer);
    this.buffer = "";
    return frame ? [frame] : [];
  }
}

/** Bytes -> SSE frames, including a UTF-8 sequence split across the last chunk. */
export class SseDecoder {
  constructor() {
    this.decoder = new TextDecoder();
    this.parser = new SseFrameParser();
  }
  push(bytes) {
    return this.parser.feed(this.decoder.decode(bytes, { stream: true }));
  }
  end() {
    return [...this.parser.feed(this.decoder.decode()), ...this.parser.flush()];
  }
}

function num(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

/**
 * turn.completed usage -> pi usage. Kagi's `input_tokens` INCLUDES cached tokens
 * (live: 7351 input with 7098 cache reads), while pi's `input` excludes them.
 * Cache writes have only been observed as 0; they are treated like reads.
 */
export function mapKagiUsage(u) {
  if (!u || typeof u !== "object") return null;
  const prompt = num(u.input_tokens);
  const cacheRead = num(u.cache_read_tokens);
  const cacheWrite = num(u.cache_write_tokens);
  const output = num(u.output_tokens);
  return {
    input: Math.max(0, prompt - cacheRead - cacheWrite),
    output,
    cacheRead,
    cacheWrite,
    totalTokens: prompt + output,
    costUsd: num(u.cost_usd),
    modelVersion: typeof u.model_version === "string" ? u.model_version : undefined,
  };
}

/** Node kind from node.created payload, falling back to the id prefix. */
export function classifyNode(nodeId, payload) {
  const kind = payload?.kind;
  if (kind === "text") return "text";
  if (kind === "activity") return payload?.type === "thinking" ? "thinking" : null;
  if (kind) return null; // assistant_message and future structural kinds
  if (typeof nodeId !== "string") return null;
  if (/^text[_-]/.test(nodeId) || nodeId === "text") return "text";
  if (/^thinking([_-]|$)/.test(nodeId)) return "thinking";
  return null;
}

/**
 * Normalises Kagi turn events. `feed(data)` takes one parsed frame payload and
 * returns events: {type: "text_start"|"thinking_start", nodeId, step},
 * {type: "text_delta"|"thinking_delta", nodeId, delta},
 * {type: "text_end"|"thinking_end", nodeId, content},
 * {type: "native_call", nodeId, name, arguments, step} when the model used its
 * native function interface (Kagi runs those on its server).
 * Usage, failure, finality, billing and unknown node kinds are kept as state.
 */
export class KagiTurnNormalizer {
  constructor() {
    this.nodes = new Map(); // nodeId -> {kind, text, open}
    this.toolNodes = new Map(); // nodeId -> {name, arguments, step, done}
    this.usage = null;
    this.rawUsage = null;
    this.failed = null; // {type, code, message}
    this.completed = false;
    this.isFinal = false;
    this.billing = null;
    this.title = null;
    this.unknownNodes = [];
  }

  #open(nodeId, kind, events, step) {
    const node = { kind, text: "", open: true };
    this.nodes.set(nodeId, node);
    events.push({ type: `${kind}_start`, nodeId, step });
    return node;
  }

  #delta(nodeId, node, delta, events) {
    if (!delta) return;
    node.text += delta;
    events.push({ type: `${node.kind}_delta`, nodeId, delta });
  }

  #close(nodeId, node, finalContent, events) {
    if (!node.open) return;
    // The completion payload carries the full text. Keep pi's invariant that a
    // block only grows through deltas: emit a missing suffix as a delta.
    if (typeof finalContent === "string" && finalContent.length > node.text.length && finalContent.startsWith(node.text)) {
      this.#delta(nodeId, node, finalContent.slice(node.text.length), events);
    }
    node.open = false;
    events.push({ type: `${node.kind}_end`, nodeId, content: node.text });
  }

  feed(data) {
    const events = [];
    if (!data || typeof data !== "object") return events;
    if (data.is_final) {
      this.isFinal = true;
      if (data.billing) this.billing = data.billing;
    }
    if (typeof data.title === "string") this.title = data.title;
    if (data.error !== undefined && data.error !== null && data.error !== "") {
      this.failed ??= { type: "error", message: typeof data.error === "string" ? data.error : JSON.stringify(data.error) };
    }
    const ev = data.event;
    if (!ev || typeof ev !== "object" || typeof ev.type !== "string") return events;
    const p = ev.payload ?? {};
    switch (ev.type) {
      case "node.created": {
        if (p.kind === "activity" && p.type === "tool_call") {
          this.toolNodes.set(ev.node_id, { name: p.tool_name, arguments: null, step: p.step, done: false });
          events.push({ type: "native_call_start", nodeId: ev.node_id, name: p.tool_name, step: p.step });
          break;
        }
        const kind = classifyNode(ev.node_id, p);
        if (!kind) {
          if (p.kind && p.kind !== "assistant_message" && !(p.kind === "activity" && p.type === "config")) {
            this.unknownNodes.push({ nodeId: ev.node_id, kind: p.kind, type: p.type });
          }
          break;
        }
        if (this.nodes.has(ev.node_id)) break;
        const node = this.#open(ev.node_id, kind, events, p.step);
        // Thinking nodes carry their first text here; it is not repeated in deltas.
        if (typeof p.content === "string") this.#delta(ev.node_id, node, p.content, events);
        break;
      }
      case "node.updated": {
        const call = this.toolNodes.get(ev.node_id);
        if (call && p.arguments && typeof p.arguments === "object") call.arguments = p.arguments;
        if (call && typeof p.tool_name === "string") call.name = p.tool_name;
        break;
      }
      case "node.delta": {
        let node = this.nodes.get(ev.node_id);
        if (!node) {
          const kind = classifyNode(ev.node_id, undefined);
          if (!kind) break;
          node = this.#open(ev.node_id, kind, events);
        }
        if (!node.open) break;
        this.#delta(ev.node_id, node, typeof p.delta === "string" ? p.delta : "", events);
        break;
      }
      case "node.completed": {
        const call = this.toolNodes.get(ev.node_id);
        if (call && !call.done) {
          call.done = true;
          if (p.arguments && typeof p.arguments === "object") call.arguments = p.arguments;
          events.push({ type: "native_call", nodeId: ev.node_id, name: call.name, arguments: call.arguments ?? {}, step: call.step });
          break;
        }
        const node = this.nodes.get(ev.node_id);
        if (node) this.#close(ev.node_id, node, p.content, events);
        break;
      }
      case "turn.completed": {
        this.completed = true;
        this.rawUsage = p.usage ?? null;
        this.usage = mapKagiUsage(p.usage);
        events.push(...this.closeAll());
        break;
      }
      case "turn.failed":
      case "turn.cancelled": {
        const detail = [p.error_code, p.message ?? p.error ?? p.error_detail].filter(Boolean).join(": ");
        this.failed = {
          type: ev.type,
          code: p.error_code,
          message: `Kagi Assistant turn ${ev.type === "turn.failed" ? "failed" : "was cancelled"}${detail ? ` (${detail})` : ""}.`,
        };
        if (p.usage) {
          this.rawUsage = p.usage;
          this.usage = mapKagiUsage(p.usage);
        }
        events.push(...this.closeAll());
        break;
      }
      default:
        break;
    }
    return events;
  }

  /** Close every open node (end of stream, failure, abort). */
  closeAll() {
    const events = [];
    for (const [nodeId, node] of this.nodes) this.#close(nodeId, node, undefined, events);
    return events;
  }
}

/** Parse an SSE frame's data field; null for keep-alives and `[DONE]`. */
export function parseFrameData(frame) {
  if (!frame?.data || frame.data === "[DONE]") return null;
  try {
    return JSON.parse(frame.data);
  } catch {
    return null;
  }
}
