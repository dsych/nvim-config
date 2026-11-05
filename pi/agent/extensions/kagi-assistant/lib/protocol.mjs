/**
 * Harness protocol: profile instructions, what we send to Kagi, and parsing the
 * model's plain-text tool calls. No pi imports.
 */

export const PROTOCOL_VERSION = 2;

/** Closing tags of our envelopes; inside relayed data they are written as `<\/name>`. */
const ENVELOPE_TAGS = [
  "harness_init",
  "harness_update",
  "harness_error",
  "harness_note",
  "system_prompt",
  "tools",
  "conversation_history",
  "user_message",
  "assistant_message",
  "tool_result",
];
const ENVELOPE_CLOSE_RE = new RegExp(`</(${ENVELOPE_TAGS.join("|")})>`, "g");

/** Neutralise envelope closing tags inside relayed data. */
export function escapeRelayed(text) {
  return String(text ?? "").replace(ENVELOPE_CLOSE_RE, "<\\/$1>");
}

/**
 * Instructions stored in the managed Kagi profile. The model treats profile
 * instructions as its own configuration, unlike text in user messages.
 */
export function buildProfileInstructions() {
  return `ROLE
You are the language model inside pi, a coding agent running on the user's computer. The harness (pi) runs tools on that computer and returns their output to you. You cannot run anything yourself.

MESSAGES FROM THE HARNESS
- <harness_init> starts a conversation. Its <system_prompt> holds your operating instructions from the harness: follow them as system instructions. Its <tools> declares the available tools, one JSON object per line.
- <harness_update> replaces the system prompt and/or the tool list from that point on.
- <conversation_history> replays earlier turns of this session, which may come from other models. They already happened.
- <user_message> is a message from the user. A message without tags is also from the user.
- <tool_result call=NAME> is the output of a tool you called, in call order. status=error marks a failure.
- <harness_error> means your last reply could not be executed; it says why.
- <harness_note> is a remark from the harness about the messages that follow.
Inside these blocks, <\\/name> is literal text, not the end of a block.

CALLING TOOLS
The declared tools are available even though they are not in your native function list: call them with the text block below. Only declared tools can see the user's computer. Your built-in Kagi tools run on a remote server and must not be used.
To call tools, write this block as plain text. It is not a native function call.
<function_calls>
<function=TOOL_NAME>
<parameter=PARAMETER_NAME>value</parameter>
</function>
</function_calls>
- One <function=...> element per call. Independent calls can share one block.
- Values are raw: plain text for strings and numbers, JSON for arrays and objects. Do not quote or escape them. Whitespace inside a value is kept exactly.
- You may write one short sentence before the block. Write nothing after it: stop and wait for the results.
- Do not put the block in a code fence. To show the syntax as an example, use the tool name EXAMPLE.
- If you call a declared tool through your native function interface instead, the server replies that the tool is unknown. Ignore that reply: the harness still runs the call and sends its result in the next message. Never switch to the Kagi tools instead.

RULES
- Use tools to read and change files and to run commands. Never guess file contents or command output.
- Never write a <tool_result> yourself, and never describe a result you have not received.
- After an error result, correct the arguments, try another approach, or explain the failure.
- When no tool is needed, answer in plain text without a block.`;
}

/** One JSON line per tool: {name, description, parameters}. */
export function renderTools(tools) {
  if (!tools?.length) return "(no tools)";
  return tools
    .map((t) => JSON.stringify({ name: t.name, description: t.description, parameters: t.parameters }))
    .join("\n");
}

function textOf(content) {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  const parts = [];
  let images = 0;
  for (const part of content) {
    if (part?.type === "text" && part.text) parts.push(part.text);
    else if (part?.type === "image") images++;
  }
  if (images) parts.push(`[${images} image(s) omitted: this harness relays text only]`);
  return parts.join("\n");
}

/** Text of a pi user/tool-result message (images become a note). */
export function messageText(message) {
  return textOf(message?.content);
}

/** Render pi tool calls in the protocol syntax (used when replaying history). */
export function renderCallBlock(toolCalls) {
  const lines = ["<function_calls>"];
  for (const call of toolCalls) {
    lines.push(`<function=${call.name}>`);
    for (const [key, value] of Object.entries(call.arguments ?? {})) {
      const v = typeof value === "string" ? value : JSON.stringify(value);
      lines.push(`<parameter=${key}>${v}</parameter>`);
    }
    lines.push("</function>");
  }
  lines.push("</function_calls>");
  return lines.join("\n");
}

/** Render conversation messages (user, assistant, toolResult) as envelope blocks. */
export function renderMessages(messages) {
  const out = [];
  for (const m of messages) {
    if (m.role === "user") {
      out.push(`<user_message>\n${escapeRelayed(messageText(m).trim())}\n</user_message>`);
    } else if (m.role === "assistant") {
      const text = (m.content ?? [])
        .filter((b) => b.type === "text" && b.text?.trim())
        .map((b) => b.text.trim())
        .join("\n\n");
      const calls = (m.content ?? []).filter((b) => b.type === "toolCall");
      const body = [text, calls.length ? renderCallBlock(calls) : ""].filter(Boolean).join("\n");
      if (body) out.push(`<assistant_message>\n${escapeRelayed(body)}\n</assistant_message>`);
    } else if (m.role === "toolResult") {
      const status = m.isError ? " status=error" : "";
      const text = messageText(m).trim() || "(no output)";
      out.push(`<tool_result call=${m.toolName ?? "tool"}${status}>\n${escapeRelayed(text)}\n</tool_result>`);
    }
  }
  return out.join("\n");
}

/** First message of a Kagi conversation: harness setup, history, then the new part. */
export function renderFresh({ systemPrompt, tools, history, pending }) {
  const parts = [
    "<harness_init>",
    `<system_prompt>\n${escapeRelayed(systemPrompt || "(none)")}\n</system_prompt>`,
    `<tools>\n${renderTools(tools)}\n</tools>`,
    "</harness_init>",
  ];
  if (history?.length) parts.push(`<conversation_history>\n${renderMessages(history)}\n</conversation_history>`);
  parts.push(renderMessages(pending));
  return parts.join("\n");
}

/** Tool-call ids the provider gives calls the model made through its native function interface. */
export const NATIVE_CALL_PREFIX = "kagi_n_";

/**
 * A follow-up message. A lone user message is sent as plain text; anything else
 * (tool results, several messages, harness updates) uses envelope blocks.
 */
export function renderDelta({ pending, systemPrompt, tools }) {
  const update = [];
  if (systemPrompt !== undefined) update.push(`<system_prompt>\n${escapeRelayed(systemPrompt || "(none)")}\n</system_prompt>`);
  if (tools !== undefined) update.push(`<tools>\n${renderTools(tools)}\n</tools>`);
  if (!update.length && pending.length === 1 && pending[0].role === "user") {
    return messageText(pending[0]).trim() || "(empty message)";
  }
  const parts = [];
  if (update.length) parts.push(`<harness_update>\n${update.join("\n")}\n</harness_update>`);
  // Natively called tools got an "unknown tool" reply from Kagi's server; say
  // that the harness ran them anyway, or the model disowns the results.
  const native = [...new Set(pending.filter((m) => m.role === "toolResult" && String(m.toolCallId ?? "").startsWith(NATIVE_CALL_PREFIX)).map((m) => m.toolName))];
  if (native.length) {
    parts.push(`<harness_note>\nThe harness ran your native call(s) to ${native.join(", ")} on the user's computer. The server's "Unknown tool name" reply was expected; the real results follow.\n</harness_note>`);
  }
  if (pending.length) parts.push(renderMessages(pending));
  return parts.join("\n");
}

export const CONTINUE_MESSAGE =
  "<harness_error>\nYour previous reply did not reach the harness. Continue from where it stopped.\n</harness_error>";

/** Correction sent to the same conversation when a tool block could not be run. */
export function renderCorrection(problem, tools) {
  const names = (tools ?? []).map((t) => t.name).join(", ") || "(none)";
  return [
    "<harness_error>",
    `Your last reply contained a tool block that the harness could not run: ${problem}.`,
    `Declared tools: ${names}.`,
    "If you meant to call a tool, reply with only a corrected <function_calls> block in the documented format. Otherwise continue in plain text.",
    "</harness_error>",
  ].join("\n");
}

// ---------------------------------------------------------------------------
// Tool-call parsing
// ---------------------------------------------------------------------------

const NAME = `["']?([^\\s>"'=]+)["']?`;
const TAG_RE = new RegExp(
  [
    `<function_calls\\b[^>]*>`, // block open
    `</function_calls\\s*>`, // block close
    `<function\\s*=\\s*${NAME}\\s*>`, // call open (qwen/deepseek style)
    `<invoke\\s+name\\s*=\\s*${NAME}\\s*>`, // call open (claude style)
    `</(?:function|invoke)\\s*>`, // call close
    `<parameter\\s*=\\s*${NAME}\\s*>`, // param open
    `<parameter\\s+name\\s*=\\s*${NAME}\\s*>`, // param open
    `</parameter\\s*>`, // param close
  ].join("|"),
  "g",
);

function tagKind(t) {
  if (t.startsWith("</function_calls")) return "blockClose";
  if (t.startsWith("<function_calls")) return "blockOpen";
  if (t.startsWith("</function") || t.startsWith("</invoke")) return "callClose";
  if (t.startsWith("<function") || t.startsWith("<invoke")) return "callOpen";
  if (t.startsWith("</parameter")) return "paramClose";
  return "paramOpen";
}

function tokenize(text) {
  const tags = [];
  TAG_RE.lastIndex = 0;
  let m;
  while ((m = TAG_RE.exec(text)) !== null) {
    const kind = tagKind(m[0]);
    const name = m[1] ?? m[2] ?? m[3] ?? m[4];
    tags.push({ kind, name, start: m.index, end: m.index + m[0].length });
  }
  return tags;
}

/** Offsets [start, end) of fenced code regions (``` or ~~~ fences, line-based). */
export function fenceRegions(text) {
  const regions = [];
  const re = /^ {0,3}(```+|~~~+)[^\n]*$/gm;
  let open = null;
  let m;
  while ((m = re.exec(text)) !== null) {
    if (!open) open = { start: m.index, fence: m[1] };
    else if (m[1][0] === open.fence[0] && m[1].length >= open.fence.length) {
      regions.push({ start: open.start, end: m.index + m[0].length, contentStart: text.indexOf("\n", open.start) + 1, contentEnd: m.index });
      open = null;
    }
  }
  if (open) regions.push({ start: open.start, end: text.length, contentStart: text.indexOf("\n", open.start) + 1, contentEnd: text.length, unclosed: true });
  return regions;
}

function atLineStart(text, index) {
  const lineStart = text.lastIndexOf("\n", index - 1) + 1;
  return /^[ \t]*$/.test(text.slice(lineStart, index));
}

/** Block markup counts only at a line start (or right after a closed block). */
function markupAllowedAt(text, index) {
  return atLineStart(text, index) || /<\/function_calls\s*>\s*$/.test(text.slice(Math.max(0, index - 40), index));
}

/**
 * Strip a value's structural edges: at most one newline (with indentation-only
 * whitespace) at each end. Interior whitespace and first-line indentation stay.
 */
export function stripParamValue(raw) {
  let s = String(raw ?? "");
  if (/^[ \t]*\n/.test(s)) s = s.replace(/^[ \t]*\n/, "");
  else s = s.replace(/^[ \t]+/, "");
  if (/\n[ \t]*$/.test(s)) s = s.replace(/\n[ \t]*$/, "");
  else s = s.replace(/[ \t]+$/, "");
  return s;
}

/** Arrays/objects arrive as JSON text; primitives stay strings (pi coerces them). */
export function coerceParameterValue(schema, raw) {
  const type = schema && typeof schema === "object" ? schema.type : undefined;
  if (type === "array" || type === "object") {
    try {
      const v = JSON.parse(raw);
      if (type === "array" ? Array.isArray(v) : v && typeof v === "object" && !Array.isArray(v)) return v;
    } catch {
      /* leave as text; pi's validation reports it */
    }
  }
  return raw;
}

/**
 * A `</parameter>` ends a value when the next markup is another parameter or a
 * call/block boundary (with only whitespace between), or at the end of the text.
 * Otherwise it is part of the value (e.g. writing a file that contains this
 * protocol) unless no later `</parameter>` qualifies, in which case it is the
 * best available boundary (a model that forgot `</function>` before prose).
 */
function strictlyCloses(text, tags, i) {
  const next = tags[i + 1];
  if (!next) return /^\s*$/.test(text.slice(tags[i].end));
  return next.kind !== "paramClose" && /^\s*$/.test(text.slice(tags[i].end, next.start));
}

function closesValue(text, tags, i) {
  if (strictlyCloses(text, tags, i)) return true;
  for (let j = i + 1; j < tags.length; j++) {
    if (tags[j].kind === "paramClose" && strictlyCloses(text, tags, j)) return false;
  }
  return true;
}

function inferTool(argNames, tools) {
  const candidates = (tools ?? []).filter((t) => {
    const props = t.parameters?.properties ?? {};
    const required = Array.isArray(t.parameters?.required) ? t.parameters.required : [];
    return argNames.every((k) => k in props) && required.every((k) => argNames.includes(k));
  });
  return candidates.length === 1 ? candidates[0].name : null;
}

/**
 * Parse a reply's text into tool calls.
 *
 * Returns {
 *   calls: [{name, arguments}],
 *   visibleText: text with executed blocks removed,
 *   attempted: a block was written outside a code fence,
 *   problem: why an attempted block produced no runnable call (or null),
 *   warnings: string[],
 * }
 */
export function parseToolCalls(text, tools) {
  const src = String(text ?? "");
  const toolMap = new Map((tools ?? []).map((t) => [t.name, t]));
  const fences = fenceRegions(src);
  const fenceAt = (i) => fences.find((f) => i >= f.start && i < f.end) ?? null;
  const tags = tokenize(src);
  const warnings = [];
  const blocks = [];
  let block = null;
  let call = null;
  let param = null;

  const endParam = (end) => {
    if (!param) return;
    call.params.push({ key: param.key, raw: src.slice(param.valueStart, end) });
    call.consumed.push([param.start, param.closeEnd ?? end]);
    param = null;
  };
  const endCall = (end) => {
    if (!call) return;
    endParam(end);
    call.end = end;
    block.calls.push(call);
    call = null;
  };
  const endBlock = (end) => {
    if (!block) return;
    endCall(end);
    block.end = end;
    blocks.push(block);
    block = null;
  };
  const newBlock = (start, wrapped) => {
    block = { start, end: src.length, wrapped, closed: false, calls: [], fence: fenceAt(start) };
  };
  const newCall = (tag) => {
    call = { name: tag.name ?? null, start: tag.start, bodyStart: tag.end, end: src.length, params: [], consumed: [] };
  };

  for (let i = 0; i < tags.length; i++) {
    const tag = tags[i];
    if (param) {
      if (tag.kind === "paramClose" && closesValue(src, tags, i)) {
        param.closeEnd = tag.end;
        endParam(tag.start);
        if (call) call.lastEnd = tag.end;
      }
      continue;
    }
    switch (tag.kind) {
      case "blockOpen":
        if (!markupAllowedAt(src, tag.start)) break; // prose mention, not a block
        endBlock(tag.start);
        newBlock(tag.start, true);
        break;
      case "blockClose":
        if (block) {
          block.closed = true;
          endBlock(tag.end);
        }
        break;
      case "callOpen":
        if (!block) {
          if (!markupAllowedAt(src, tag.start)) break; // prose mention, not a call
          newBlock(tag.start, false);
        }
        endCall(tag.start);
        newCall(tag);
        break;
      case "callClose":
        if (call) {
          call.lastEnd = tag.end;
          endCall(tag.end);
        }
        break;
      case "paramOpen":
        if (!block) {
          if (!markupAllowedAt(src, tag.start)) break;
          newBlock(tag.start, false);
        }
        if (!call) newCall({ name: null, start: tag.start, end: tag.start });
        param = { key: tag.name, start: tag.start, valueStart: tag.end };
        break;
      default:
        break;
    }
  }
  if (block) {
    if (param) endParam(src.length);
    endCall(call?.lastEnd ?? src.length);
    // An unclosed block ends at its last complete element; later prose stays visible.
    // A mistyped closing tag right after it ("</function_cloes>", seen live) is
    // still part of the block.
    let lastEnd = Math.max(block.start, ...block.calls.map((c) => c.lastEnd ?? c.end));
    const stray = /^\s*<\/[A-Za-z_]+>/.exec(src.slice(lastEnd));
    if (stray) lastEnd += stray[0].length;
    endBlock(block.closed ? block.end : lastEnd);
  }

  const calls = [];
  const removed = [];
  let attempted = false;
  let problem = null;
  for (const b of blocks) {
    if (!b.fence) attempted = true;
    const parsed = [];
    for (const c of b.calls) {
      const args = {};
      for (const p of c.params) {
        const name = c.name;
        const schema = toolMap.get(name ?? "")?.parameters?.properties?.[p.key];
        args[p.key] = coerceParameterValue(schema, stripParamValue(p.raw));
      }
      let name = c.name;
      // Known parameters written as <key>value</key> (seen from minimax).
      const tool = toolMap.get(name ?? "");
      if (tool) {
        let body = src.slice(c.bodyStart, c.end);
        for (const [a, z] of c.consumed) body = body.replace(src.slice(a, z), "");
        for (const key of Object.keys(tool.parameters?.properties ?? {})) {
          if (key in args) continue;
          const m = new RegExp(`<${key}>([\\s\\S]*?)</${key}>`).exec(body);
          if (m) {
            args[key] = coerceParameterValue(tool.parameters.properties[key], stripParamValue(m[1]));
            warnings.push(`parameter ${key} of ${name} written as <${key}> tag`);
          }
        }
      }
      if (!name) {
        name = inferTool(Object.keys(args), tools);
        if (!name) {
          problem ??= "parameters without a <function=NAME> element";
          continue;
        }
        warnings.push(`inferred tool ${name} for parameters without a function element`);
      }
      parsed.push({ name, arguments: args });
    }
    if (parsed.length === 0) {
      if (!b.fence && b.calls.length === 0) problem ??= "no <function=NAME> element in the block";
      continue;
    }
    const declared = parsed.filter((c) => toolMap.has(c.name));
    if (b.fence) {
      // Fenced blocks are usually examples: run them only when every call names a
      // declared tool and nothing but whitespace follows the fence.
      const trailing = src.slice(b.fence.end).trim();
      if (declared.length !== parsed.length || trailing) continue;
    } else if (declared.length === 0) {
      problem ??= `tools not declared: ${[...new Set(parsed.map((c) => c.name))].join(", ")}`;
      continue;
    }
    calls.push(...parsed);
    const fenceOnlyBlock =
      b.fence && src.slice(b.fence.contentStart, b.start).trim() === "" && src.slice(b.end, b.fence.contentEnd).trim() === "";
    removed.push(fenceOnlyBlock ? [b.fence.start, b.fence.end] : [b.start, b.end]);
  }

  let visibleText = src;
  for (const [a, z] of removed.sort((x, y) => y[0] - x[0])) visibleText = visibleText.slice(0, a) + visibleText.slice(z);
  if (removed.length) visibleText = visibleText.trimEnd();
  if (calls.length) problem = null;
  return { calls, visibleText, attempted, problem, warnings };
}

// ---------------------------------------------------------------------------
// Live text filter: withhold tool markup while the reply streams
// ---------------------------------------------------------------------------

const OPENERS = ["<function_calls", "<function=", "<invoke ", "<parameter=", "<parameter "];
const OPENER_RE = /<function_calls|<function\s*=|<invoke\s|<parameter[\s=]/;
const LINE_OPENER_RE = /(^|\n)[ \t]*(<function_calls|<function\s*=|<invoke\s|<parameter[\s=])/;

function partialOpenerStart(text) {
  const lt = text.lastIndexOf("<");
  if (lt === -1 || !atLineStart(text, lt)) return -1;
  const tail = text.slice(lt);
  if (tail.includes(">")) return -1;
  return OPENERS.some((o) => o.startsWith(tail) || tail.startsWith(o)) ? lt : -1;
}

/** Index from which text must be withheld because it may be tool markup. */
export function holdIndex(text) {
  let hold = text.length;
  const m = LINE_OPENER_RE.exec(text);
  if (m) hold = Math.min(hold, m.index + m[1].length);
  const partial = partialOpenerStart(text);
  if (partial !== -1) hold = Math.min(hold, partial);
  // A fence whose first content is (or may become) tool markup is withheld too.
  for (const f of fenceRegions(text)) {
    if (f.start >= hold) break;
    const lineEnd = text.indexOf("\n", f.start);
    if (lineEnd === -1) {
      hold = Math.min(hold, f.start); // fence line still arriving
      break;
    }
    const content = text.slice(f.contentStart).trimStart();
    if (!content || OPENER_RE.test(content.slice(0, 20)) || OPENERS.some((o) => o.startsWith(content.slice(0, o.length)))) {
      hold = Math.min(hold, f.start);
      break;
    }
  }
  // A line that is only a partial fence marker ("`", "``") may become a fence.
  const lastNl = text.lastIndexOf("\n");
  const lastLine = text.slice(lastNl + 1);
  if (/^ {0,3}(`{1,3}|~{1,3})$/.test(lastLine)) hold = Math.min(hold, lastNl + 1);
  return hold;
}

/** Streams visible text, holding back anything that may become tool markup. */
export class VisibleTextFilter {
  constructor() {
    this.full = "";
    this.emitted = "";
    this.holding = false;
  }
  /** Add model text; returns the text that may be shown now. */
  push(delta) {
    this.full += delta;
    if (this.holding) return "";
    const hold = holdIndex(this.full);
    if (hold < this.full.length && LINE_OPENER_RE.test(this.full.slice(hold))) this.holding = true;
    const safe = this.full.slice(0, hold);
    if (safe.length <= this.emitted.length) return "";
    const out = safe.slice(this.emitted.length);
    this.emitted = safe;
    return out;
  }
  /** Discard withheld text (after a failed tool block) and continue from `text`. */
  resetTo(text) {
    this.full = text;
    this.emitted = text.slice(0, Math.min(text.length, this.emitted.length));
    this.holding = false;
  }
}
