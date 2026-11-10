// node --test pi/tests/kagi-assistant.test.mjs
// Pure-logic tests for the Kagi Assistant extension (no pi, no network).
import assert from "node:assert/strict";
import fs from "node:fs";
import fsp from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";

const lib = new URL("../agent/extensions/kagi-assistant/lib/", import.meta.url);
const { normalizeSessionToken, resolveSessionToken, readConfig, writeConfig, MAX_THREADS } = await import(new URL("config.mjs", lib));
const { createKagiClient, KagiApiError, parseErrorBody, waitForTurn } = await import(new URL("client.mjs", lib));
const { SseFrameParser, SseDecoder, KagiTurnNormalizer, mapKagiUsage, parseFrameData, classifyNode } = await import(new URL("stream.mjs", lib));
const { buildThinkingLevelMap, mapCatalog, resolveEffort } = await import(new URL("catalog.mjs", lib));
const { KagiBudget, formatUsd } = await import(new URL("budget.mjs", lib));
const protocol = await import(new URL("protocol.mjs", lib));
const { parseToolCalls, VisibleTextFilter, escapeRelayed, renderFresh, renderDelta, stripParamValue, renderCorrection, CONTINUE_MESSAGE } = protocol;
const { planDelivery, stateAfterSend, loadThreadState, hashMessages, canonicalMessage } = await import(new URL("thread.mjs", lib));

const fixture = (name) => fs.readFileSync(new URL(`fixtures/kagi/${name}`, import.meta.url), "utf8");
const tmpHome = () => fs.mkdtempSync(path.join(os.tmpdir(), "kagi-test-"));

// ---------------------------------------------------------------------------
// Token and config
// ---------------------------------------------------------------------------

test("session token: raw value, session link, and empty input", () => {
  assert.equal(normalizeSessionToken("  abc.def \n"), "abc.def");
  assert.equal(normalizeSessionToken("https://kagi.com/search?token=abc%2Edef&x=1"), "abc.def");
  assert.equal(normalizeSessionToken("https://kagi.com/search?q=1"), null);
  assert.equal(normalizeSessionToken(""), null);
  assert.equal(normalizeSessionToken(undefined), null);
});

test("session token: env, then /kagi-login config, then the token file", async () => {
  const home = tmpHome();
  fs.mkdirSync(path.join(home, ".pi"));
  fs.writeFileSync(path.join(home, ".kagi_session_token"), "https://kagi.com/search?token=fromfile\n");
  assert.deepEqual(await resolveSessionToken({ env: {}, home }), { token: "fromfile", source: "~/.kagi_session_token" });
  fs.writeFileSync(path.join(home, ".pi/kagi.json"), JSON.stringify({ sessionToken: "fromlogin" }));
  assert.equal((await resolveSessionToken({ env: {}, home })).token, "fromlogin");
  assert.equal((await resolveSessionToken({ env: { KAGI_SESSION_TOKEN: "fromenv" }, home })).token, "fromenv");
});

test("readConfig: missing, array and corrupt files read as {} (corruption reported)", async () => {
  const home = tmpHome();
  assert.deepEqual(await readConfig({ home }), {});
  fs.mkdirSync(path.join(home, ".pi"));
  fs.writeFileSync(path.join(home, ".pi/kagi.json"), "[1,2]");
  let corrupt = 0;
  assert.deepEqual(await readConfig({ home, onCorrupt: () => corrupt++ }), {});
  fs.writeFileSync(path.join(home, ".pi/kagi.json"), "{truncated");
  assert.deepEqual(await readConfig({ home, onCorrupt: () => corrupt++ }), {});
  assert.equal(corrupt, 2);
});

test("writeConfig: 0600, merges threads/profiles by key, null removes", async () => {
  const home = tmpHome();
  await writeConfig({ sessionToken: "t", threads: { a: { v: 2 }, b: { v: 2 } } }, { home });
  const next = await writeConfig({ threads: { a: null, c: { v: 2 } }, profiles: { m: { uuid: "u" } } }, { home });
  assert.deepEqual(Object.keys(next.threads).sort(), ["b", "c"]);
  assert.equal(next.sessionToken, "t");
  assert.equal(fs.statSync(path.join(home, ".pi/kagi.json")).mode & 0o777, 0o600);
  assert.deepEqual(fs.readdirSync(path.join(home, ".pi")), ["kagi.json"]);
});

test("writeConfig: a corrupt file is kept as a backup, not silently replaced", async () => {
  const home = tmpHome();
  fs.mkdirSync(path.join(home, ".pi"));
  fs.writeFileSync(path.join(home, ".pi/kagi.json"), '{"sessionToken": "keep-me"');
  await writeConfig({ budgetUsd: 5 }, { home, now: () => 123 });
  assert.equal(fs.readFileSync(path.join(home, ".pi/kagi.json.corrupt-123"), "utf8"), '{"sessionToken": "keep-me"');
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(home, ".pi/kagi.json"), "utf8")), { budgetUsd: 5 });
});

test("writeConfig: keeps only the most recently updated threads", async () => {
  const home = tmpHome();
  const threads = {};
  for (let i = 0; i < MAX_THREADS + 5; i++) threads[`s${i}`] = { updatedAt: i };
  const next = await writeConfig({ threads }, { home });
  assert.equal(Object.keys(next.threads).length, MAX_THREADS);
  assert.ok(!("s0" in next.threads) && `s${MAX_THREADS + 4}` in next.threads);
});

// ---------------------------------------------------------------------------
// HTTP client
// ---------------------------------------------------------------------------

function fakeFetch(handler) {
  const calls = [];
  const fn = async (url, init) => {
    calls.push({ url, init, body: init.body ? JSON.parse(init.body) : undefined });
    const r = await handler(url, init, calls.length);
    return new Response(typeof r.body === "string" ? r.body : JSON.stringify(r.body ?? {}), { status: r.status ?? 200, headers: r.headers });
  };
  fn.calls = calls;
  return fn;
}

test("client: cookie header, caller headers, onResponse before the body, JSON errors", async () => {
  const f = fakeFetch((url) =>
    url.endsWith("/respond")
      ? { status: 409, body: { error: { code: "request_state_changed", message: "The conversation changed", request_id: "r1" } } }
      : { body: { assistant_turn_uuid: "t" } },
  );
  const seen = [];
  const client = createKagiClient({ token: "secret", fetch: f, headers: { "X-Extra": "1", "User-Agent": null } });
  await client.startConversation({ content: "hi" }, { onResponse: (res) => seen.push(res.status) });
  assert.equal(f.calls[0].init.headers.Cookie, "kagi_session=secret");
  assert.equal(f.calls[0].init.headers["X-Extra"], "1");
  assert.ok(!("User-Agent" in f.calls[0].init.headers));
  assert.deepEqual(seen, [200]);
  await assert.rejects(client.respond("b", { content: "x" }), (e) => e instanceof KagiApiError && e.isBusy && e.code === "request_state_changed");
});

test("client: Kagi 404 bodies distinguish a deleted profile from an expired branch", () => {
  const profile = new KagiApiError({ surface: "s", status: 404, ...parseErrorBody('{"error":{"code":"not_found","message":"Custom assistant not found"}}') });
  const branch = new KagiApiError({ surface: "s", status: 404, ...parseErrorBody('{"error":{"code":"not_found","message":"Branch not found"}}') });
  assert.ok(profile.isProfileMissing && !profile.isBranchMissing);
  assert.ok(branch.isBranchMissing && !branch.isProfileMissing);
  const plan = new KagiApiError({ surface: "s", status: 403, code: "forbidden", message: "requires Unlimited plan" });
  assert.ok(!plan.isAuth);
  assert.match(plan.message, /Unlimited plan/);
});

test("client: errors never contain the token", async () => {
  const f = fakeFetch(() => ({ status: 500, body: "boom secret-token boom" }));
  const client = createKagiClient({ token: "secret-token", fetch: f });
  await assert.rejects(client.init(), (e) => !e.message.includes("secret-token"));
});

test("waitForTurn polls until the turn is no longer running", async () => {
  const statuses = ["running", "running", "completed"];
  const client = { getTurn: async () => ({ status: statuses.shift(), cost_usd: 0.002 }) };
  const turn = await waitForTurn(client, "t", { intervalMs: 1 });
  assert.equal(turn.status, "completed");
  assert.equal(statuses.length, 0);
});

// ---------------------------------------------------------------------------
// SSE and turn events (fixtures captured live, ids anonymised)
// ---------------------------------------------------------------------------

function normalize(sse, chunkSize = 37) {
  const decoder = new SseDecoder();
  const norm = new KagiTurnNormalizer();
  const events = [];
  const bytes = new TextEncoder().encode(sse);
  for (let i = 0; i < bytes.length; i += chunkSize) {
    for (const f of decoder.push(bytes.slice(i, i + chunkSize))) events.push(...norm.feed(parseFrameData(f)));
  }
  for (const f of decoder.end()) events.push(...norm.feed(parseFrameData(f)));
  events.push(...norm.closeAll());
  return { norm, events };
}

test("SSE framing: CRLF, comments and a frame split across chunks", () => {
  const p = new SseFrameParser();
  assert.deepEqual(p.feed(": keep-alive\r\n\r\nid: 1\r\ndata: {\"a\""), []);
  assert.deepEqual(p.feed(":1}\r\n\r\n"), [{ id: "1", data: '{"a":1}' }]);
  assert.deepEqual(p.flush(), []);
});

test("SSE decoding keeps a multi-byte character split across chunks", () => {
  const d = new SseDecoder();
  const bytes = new TextEncoder().encode('data: {"t":"héllo 🙂"}\n\n');
  const frames = [...d.push(bytes.slice(0, 13)), ...d.push(bytes.slice(13, 22)), ...d.push(bytes.slice(22)), ...d.end()];
  assert.equal(JSON.parse(frames[0].data).t, "héllo 🙂");
});

test("text turn: one text block, structural nodes ignored, usage and billing captured", () => {
  const { norm, events } = normalize(fixture("text-turn.sse"));
  assert.deepEqual(events.map((e) => e.type), ["text_start", "text_delta", "text_delta", "text_end"]);
  assert.equal(events.at(-1).content, "ALPHA");
  assert.ok(norm.completed && norm.isFinal && !norm.failed);
  assert.deepEqual(norm.usage, { input: 1770, output: 5, cacheRead: 1122, cacheWrite: 0, totalTokens: 2897, costUsd: 0.000652, modelVersion: "accounts/fireworks/models/deepseek-v4p1-flash-1017" });
  assert.equal(norm.billing.usage.included_cost_limit_usd, 100);
});

test("thinking turn: the first thinking text comes from node.created", () => {
  const { events } = normalize(fixture("thinking-turn.sse"));
  const thinking = events.filter((e) => e.type === "thinking_end").map((e) => e.content);
  const text = events.filter((e) => e.type === "text_end").map((e) => e.content);
  assert.deepEqual(thinking, ["17 × 23 = 391."]);
  assert.deepEqual(text, ["391"]);
});

test("aborted turn: no usage, open blocks are closed", () => {
  const { norm, events } = normalize(fixture("aborted-turn.sse"));
  assert.equal(norm.completed, false);
  assert.equal(norm.usage, null);
  const starts = events.filter((e) => e.type.endsWith("_start")).length;
  const ends = events.filter((e) => e.type.endsWith("_end")).length;
  assert.equal(starts, ends);
});

test("node completion content fills a missing suffix as a delta", () => {
  const norm = new KagiTurnNormalizer();
  const ev = (type, node_id, payload) => ({ event: { type, node_id, payload } });
  const out = [
    ...norm.feed(ev("node.created", "text_x", { kind: "text" })),
    ...norm.feed(ev("node.delta", "text_x", { delta: "Hel" })),
    ...norm.feed(ev("node.completed", "text_x", { content: "Hello" })),
  ];
  assert.deepEqual(out.map((e) => e.delta ?? e.content ?? e.type), ["text_start", "Hel", "lo", "Hello"]);
});

test("turn.failed reports the error code and closes open blocks", () => {
  const norm = new KagiTurnNormalizer();
  norm.feed({ event: { type: "node.created", node_id: "text_1", payload: { kind: "text" } } });
  const out = norm.feed({ event: { type: "turn.failed", payload: { error_code: "rate_limited" } } });
  assert.match(norm.failed.message, /rate_limited/);
  assert.deepEqual(out.map((e) => e.type), ["text_end"]);
});

test("native tool calls surface with their final arguments (captured live from Claude)", () => {
  const norm = new KagiTurnNormalizer();
  const ev = (type, node_id, payload) => ({ event: { type, node_id, payload } });
  const out = [
    ...norm.feed(ev("node.created", "toolu_1", { kind: "activity", type: "tool_call", tool_name: "read", arguments_partial: null, step: 1 })),
    ...norm.feed(ev("node.updated", "toolu_1", { status: "running", tool_name: "read", arguments: { path: "calc.py" } })),
    ...norm.feed(ev("node.completed", "toolu_1", { result: { content: "Unknown tool name: 'read'." }, arguments: { path: "calc.py" }, tool_error: true })),
    ...norm.feed(ev("node.created", "text_2", { kind: "text", step: 2 })),
  ];
  assert.deepEqual(out, [
    { type: "native_call_start", nodeId: "toolu_1", name: "read", step: 1 },
    { type: "native_call", nodeId: "toolu_1", name: "read", arguments: { path: "calc.py" }, step: 1 },
    { type: "text_start", nodeId: "text_2", step: 2 },
  ]);
  assert.deepEqual(norm.unknownNodes, []);
});

test("node classification prefers payload.kind and falls back to the id", () => {
  assert.equal(classifyNode("x", { kind: "text" }), "text");
  assert.equal(classifyNode("x", { kind: "activity", type: "thinking" }), "thinking");
  assert.equal(classifyNode("config_1", { kind: "activity", type: "config" }), null);
  assert.equal(classifyNode("text-2", undefined), "text");
  assert.equal(classifyNode("thinking", undefined), "thinking");
});

test("usage: pi input excludes cached tokens; total counts the prompt once", () => {
  assert.deepEqual(mapKagiUsage({ input_tokens: 7351, output_tokens: 4, cache_read_tokens: 7098, cache_write_tokens: 0, cost_usd: 0.000148 }), {
    input: 253,
    output: 4,
    cacheRead: 7098,
    cacheWrite: 0,
    totalTokens: 7355,
    costUsd: 0.000148,
    modelVersion: undefined,
  });
});

// ---------------------------------------------------------------------------
// Catalog and thinking levels
// ---------------------------------------------------------------------------

test("catalog: hides unusable models; effort options decide reasoning", () => {
  const { models, meta } = mapCatalog({
    has_unlimited_access: false,
    models: {
      models: [
        { id: "deepseek", display_name: "DS", context_window: 1048576, parameters: { reasoning_effort: { options: ["none", "low", "high", "max"] } } },
        { id: "opus", access_level: "unlimited", parameters: { reasoning_effort: { options: ["low"] } } },
        { id: "quick", requires_search: true },
        { id: "old", retired: true },
        { id: "deepseek" },
      ],
    },
  });
  assert.deepEqual(models.map((m) => m.id), ["deepseek", "quick"]);
  assert.equal(models[0].reasoning, true);
  assert.deepEqual(models[0].thinkingLevelMap, { off: "none", minimal: null, low: "low", medium: null, high: "high", xhigh: null, max: "max" });
  assert.equal(models[1].reasoning, false);
  assert.equal(meta.get("quick").requiresSearch, true);
});

test("resolveEffort: never leaves a reasoning model on the server default", () => {
  const map = buildThinkingLevelMap(["low", "high"]);
  assert.equal(resolveEffort(map, "high"), "high");
  assert.equal(resolveEffort(map, undefined), "low"); // pi "off" without a "none" option
  assert.equal(resolveEffort(buildThinkingLevelMap(["none", "low"]), undefined), "none");
  assert.equal(resolveEffort(null, "high"), undefined);
});

// ---------------------------------------------------------------------------
// Budget
// ---------------------------------------------------------------------------

test("budget: 80% and cap warnings once each; blocked at the cap", () => {
  const b = new KagiBudget(1);
  assert.deepEqual(b.record(0.5), []);
  assert.equal(b.record(0.35)[0].level, "warning");
  assert.deepEqual(b.record(0.01), []);
  assert.equal(b.record(0.2)[0].level, "error");
  assert.equal(b.gate(), "blocked");
});

test("budget: a resumed session over 80% or the cap does not warn again", () => {
  const b = new KagiBudget(1);
  b.seed(0.9);
  assert.deepEqual(b.record(0.01), []);
  b.seed(1.2);
  assert.deepEqual(b.record(0.01), []);
  assert.equal(b.gate(), "blocked");
  b.setLimit(5);
  assert.equal(b.gate(), "ok");
  assert.equal(formatUsd(0.000652), "$0.0007");
  assert.equal(formatUsd(2.5), "$2.50");
});

// ---------------------------------------------------------------------------
// Tool-call parsing (cases taken from real Kagi replies)
// ---------------------------------------------------------------------------

const TOOLS = [
  { name: "bash", description: "Run", parameters: { type: "object", properties: { command: { type: "string" }, timeout: { type: "number" } }, required: ["command"] } },
  { name: "read", description: "Read", parameters: { type: "object", properties: { path: { type: "string" }, offset: { type: "number" } }, required: ["path"] } },
  { name: "edit", description: "Edit", parameters: { type: "object", properties: { path: { type: "string" }, edits: { type: "array" } }, required: ["path", "edits"] } },
  { name: "mcp.fs:read", description: "MCP", parameters: { type: "object", properties: { p: { type: "string" } } } },
];
const calls = (text) => parseToolCalls(text, TOOLS).calls;
const block = (inner) => `<function_calls>\n${inner}\n</function_calls>`;

test("parse: canonical block, values kept as text for pi to coerce", () => {
  assert.deepEqual(calls(block("<function=bash>\n<parameter=command>ls -la</parameter>\n<parameter=timeout>60</parameter>\n</function>")), [
    { name: "bash", arguments: { command: "ls -la", timeout: "60" } },
  ]);
});

test("parse: prose before the block stays visible", () => {
  const r = parseToolCalls(`I'll start by finding the code.\n\n${block("<function=bash>\n<parameter=command>pwd</parameter>\n</function>")}`, TOOLS);
  assert.equal(r.calls.length, 1);
  assert.equal(r.visibleText, "I'll start by finding the code.");
});

test("parse: missing </function_calls> and missing </function>", () => {
  assert.equal(calls("<function_calls>\n<function=read>\n<parameter=path>AUDIT.md</parameter>\n</function>\n").length, 1);
  const r = parseToolCalls("<function_calls>\n<function=bash>\n<parameter=command>ls</parameter>\nThen I will check.", TOOLS);
  assert.deepEqual(r.calls, [{ name: "bash", arguments: { command: "ls" } }]);
  assert.match(r.visibleText, /Then I will check\./);
});

test("parse: a mistyped block closer is consumed with the block", () => {
  const r = parseToolCalls("<function_calls>\n<function=edit>\n<parameter=path>a</parameter>\n<parameter=edits>[]</parameter>\n</function>\n</function_cloes>", TOOLS);
  assert.equal(r.calls.length, 1);
  assert.equal(r.visibleText, "");
});

test("parse: stray quote in the name and a parameter written as its own tag", () => {
  const r = parseToolCalls(block('<function=read">\n<parameter=path>kagi-core.mjs</parameter>\n<offset>320</offset>\n</function>'), TOOLS);
  assert.deepEqual(r.calls, [{ name: "read", arguments: { path: "kagi-core.mjs", offset: "320" } }]);
});

test("parse: a parameter opened as its own tag and closed with </parameter> (seen live)", () => {
  const r = parseToolCalls("<function=read>\n<path>hello.txt</parameter>\n</function>", TOOLS);
  assert.deepEqual(r.calls, [{ name: "read", arguments: { path: "hello.txt" } }]);
  assert.equal(r.visibleText, "");
});

test("parse: parameters without a function element infer the only matching tool", () => {
  assert.deepEqual(calls(block("<parameter=command>node -e 1</parameter>")), [{ name: "bash", arguments: { command: "node -e 1" } }]);
  const r = parseToolCalls(block("<parameter=unknown>1</parameter>"), TOOLS);
  assert.equal(r.calls.length, 0);
  assert.match(r.problem, /without a <function=NAME>/);
});

test("parse: two blocks back to back, Claude-style invoke, dotted and colon names", () => {
  const two = `${block("<function=bash>\n<parameter=command>pwd</parameter>\n</function>")}${block("<function=read>\n<parameter=path>a</parameter>\n</function>")}`;
  assert.deepEqual(calls(two).map((c) => c.name), ["bash", "read"]);
  assert.deepEqual(calls(block('<invoke name="bash">\n<parameter name="command">echo hi</parameter>\n</invoke>')), [
    { name: "bash", arguments: { command: "echo hi" } },
  ]);
  assert.deepEqual(calls(block("<function=mcp.fs:read>\n<parameter=p>x</parameter>\n</function>")), [{ name: "mcp.fs:read", arguments: { p: "x" } }]);
});

test("parse: whitespace inside values survives; JSON arrays are parsed", () => {
  const r = calls(block('<function=edit>\n<parameter=path>a.ts</parameter>\n<parameter=edits>[{"oldText":"  x","newText":"  y\\n"}]</parameter>\n</function>'));
  assert.deepEqual(r[0].arguments.edits, [{ oldText: "  x", newText: "  y\n" }]);
  assert.equal(stripParamValue("\n  indented\n\n"), "  indented\n");
});

test("parse: protocol text inside a value does not end the value", () => {
  const r = calls(block("<function=bash>\n<parameter=command>cat <<EOF\n<parameter=x>y</parameter> and </function_calls>\nEOF</parameter>\n</function>"));
  assert.equal(r[0].arguments.command, "cat <<EOF\n<parameter=x>y</parameter> and </function_calls>\nEOF");
});

test("parse: fenced examples and prose mentions are not executed", () => {
  const example = "Here is the syntax:\n\n```\n" + block('<invoke name="TOOL_NAME">\n<parameter name="P">V</parameter>\n</invoke>') + "\n```\nThat is all.";
  const r = parseToolCalls(example, TOOLS);
  assert.equal(r.calls.length, 0);
  assert.equal(r.attempted, false);
  assert.equal(r.visibleText, example);
  const mention = parseToolCalls("The parser looks for `<function_calls>` blocks and <function=NAME> tags.", TOOLS);
  assert.deepEqual([mention.calls.length, mention.attempted], [0, false]);
});

test("parse: a fenced block of declared tools ending the reply is executed", () => {
  const r = parseToolCalls("Running it:\n```xml\n" + block("<function=bash>\n<parameter=command>ls</parameter>\n</function>") + "\n```", TOOLS);
  assert.equal(r.calls.length, 1);
  assert.equal(r.visibleText, "Running it:");
});

test("parse: only undeclared tools -> problem for a correction, no calls", () => {
  const r = parseToolCalls(block("<function=list_directory>\n<parameter=path>.</parameter>\n</function>"), TOOLS);
  assert.deepEqual([r.calls.length, r.attempted], [0, true]);
  assert.match(r.problem, /list_directory/);
});

test("parse: a mix of declared and undeclared tools runs all (pi reports the unknown one)", () => {
  assert.deepEqual(calls(block("<function=bash>\n<parameter=command>ls</parameter>\n</function>\n<function=nope>\n</function>")).map((c) => c.name), ["bash", "nope"]);
});

test("parse: plain answers are untouched", () => {
  const r = parseToolCalls("Paris is the capital of France.", TOOLS);
  assert.deepEqual(r, { calls: [], visibleText: "Paris is the capital of France.", attempted: false, problem: null, warnings: [] });
});

test("live filter: markup is withheld while prose and code stream", () => {
  const f = new VisibleTextFilter();
  let shown = "";
  for (const d of ["I will list", " files.\n\n<fun", "ction_calls>\n<function=bash>", "\n</function_calls>"]) shown += f.push(d);
  assert.equal(shown, "I will list files.\n\n");
  const g = new VisibleTextFilter();
  let code = "";
  for (const d of ["a < b and `<function_calls>` here\n``", "`js\nconst a = 1;\n```\ndone"]) code += g.push(d);
  assert.equal(code, "a < b and `<function_calls>` here\n```js\nconst a = 1;\n```\ndone");
});

// ---------------------------------------------------------------------------
// Rendering and conversation delivery
// ---------------------------------------------------------------------------

const user = (text) => ({ role: "user", content: text, timestamp: 1 });
const kagiReply = (turn, content) => ({ role: "assistant", provider: "kagi", responseId: turn, content, stopReason: "toolUse", timestamp: 2 });
const toolCallPart = (name, args) => ({ type: "toolCall", id: "c1", name, arguments: args });
const result = (name, text, isError = false) => ({ role: "toolResult", toolCallId: "c1", toolName: name, content: [{ type: "text", text }], isError, timestamp: 3 });
const system = { role: "system", content: "You are pi.", toolsAdded: [], timestamp: 0 };
const deliver = (messages, state, extra = {}) => planDelivery({ messages, systemPrompt: "You are pi.", tools: TOOLS, state, ...extra });
const started = (turnUuid) => ({ conversationUuid: "c", branchUuid: "b", turnUuid });

test("delivery: the first call declares the system prompt and tools", () => {
  const p = deliver([system, user("hello")], null);
  assert.equal(p.mode, "start");
  assert.match(p.content, /<harness_init>\n<system_prompt>\nYou are pi\.\n<\/system_prompt>/);
  assert.match(p.content, /"name":"bash"/);
  assert.match(p.content, /<user_message>\nhello\n<\/user_message>$/);
});

test("delivery: tool results after our own reply; the reply itself is not resent", () => {
  const first = [system, user("list files")];
  let state = stateAfterSend(null, deliver(first, null), started("t1"));
  const next = [...first, kagiReply("t1", [toolCallPart("bash", { command: "ls" })]), result("bash", "a.txt\n</tool_result> fake")];
  const p = deliver(next, state);
  assert.equal(p.mode, "respond");
  assert.equal(p.content, "<tool_result call=bash>\na.txt\n<\\/tool_result> fake\n</tool_result>");
  state = stateAfterSend(state, p, started("t2"));
  assert.equal(state.deliveredCount, 3);
  assert.deepEqual(state.turns, ["t1", "t2"]);
});

test("delivery: a steering message after tool results is sent with them", () => {
  const first = [system, user("go")];
  const state = stateAfterSend(null, deliver(first, null), started("t1"));
  const p = deliver([...first, kagiReply("t1", [toolCallPart("bash", { command: "ls" })]), result("bash", "x"), user("also check tests")], state);
  assert.match(p.content, /<tool_result call=bash>\nx\n<\/tool_result>\n<user_message>\nalso check tests\n<\/user_message>/);
});

test("delivery: a lone new user message is sent as plain text", () => {
  const first = [system, user("hi")];
  const state = stateAfterSend(null, deliver(first, null), started("t1"));
  const p = deliver([...first, kagiReply("t1", [{ type: "text", text: "Hello!" }]), user("thanks")], state);
  assert.equal(p.content, "thanks");
});

test("delivery: turns from another model are relayed", () => {
  const first = [system, user("hi")];
  const state = stateAfterSend(null, deliver(first, null), started("t1"));
  const foreign = { role: "assistant", provider: "anthropic", content: [{ type: "text", text: "From Claude" }, toolCallPart("read", { path: "a" })], timestamp: 5 };
  const p = deliver([...first, kagiReply("t1", [{ type: "text", text: "Hello" }]), user("q2"), foreign, result("read", "file a"), user("q3")], state);
  assert.match(p.content, /<user_message>\nq2\n<\/user_message>\n<assistant_message>\nFrom Claude\n<function_calls>\n<function=read>\n<parameter=path>a<\/parameter>/);
  assert.match(p.content, /<tool_result call=read>\nfile a\n<\/tool_result>\n<user_message>\nq3\n<\/user_message>$/);
});

test("delivery: an edited, rewound or compacted history starts a new conversation with the transcript", () => {
  const first = [system, user("question one")];
  const state = stateAfterSend(null, deliver(first, null), started("t1"));
  const edited = deliver([system, user("question one, edited")], state);
  assert.deepEqual([edited.mode, edited.reason], ["start", "history-changed"]);
  const later = [system, user("summary of earlier work"), kagiReply("t9", [{ type: "text", text: "ok" }]), user("continue")];
  const compacted = deliver(later, state);
  assert.equal(compacted.mode, "start");
  assert.match(compacted.content, /<conversation_history>\n<user_message>\nsummary of earlier work[\s\S]*<assistant_message>\nok\n<\/assistant_message>\n<\/conversation_history>\n<user_message>\ncontinue/);
});

// A message an extension's `context` hook adds to one request (context-mode does this once per
// run): pi passes it without a timestamp, and the next request no longer contains it.
const requestLocal = (text) => ({ role: "user", content: text });

test("delivery: a request-local message follows the prompt instead of pushing it into the history", () => {
  const p = deliver([system, user("read hello.txt"), requestLocal("context note")], null);
  assert.equal(p.mode, "start");
  assert.ok(!p.content.includes("<conversation_history>"), p.content);
  assert.match(p.content, /<\/harness_init>\n<user_message>\nread hello\.txt\n<\/user_message>\n<user_message>\ncontext note\n<\/user_message>$/);
  assert.equal(p.deliveredCount, 1);
});

test("delivery: a request-local message that is gone on the next call does not restart the conversation", () => {
  const first = [system, user("read hello.txt")];
  let state = stateAfterSend(null, deliver([...first, requestLocal("note 1")], null), started("t1"));
  const afterTool = [...first, kagiReply("t1", [toolCallPart("read", { path: "hello.txt" })]), result("read", "alpha")];
  const p = deliver(afterTool, state);
  assert.deepEqual([p.mode, p.reason], ["respond", "delta"]);
  assert.equal(p.content, "<tool_result call=read>\nalpha\n</tool_result>");
  state = stateAfterSend(state, p, started("t2"));
  // The next prompt brings a new request-local message; both are relayed, in order.
  const answer = { ...kagiReply("t2", [{ type: "text", text: "It says alpha." }]), stopReason: "stop" };
  const next = deliver([...afterTool, answer, user("thanks"), requestLocal("note 2")], state);
  assert.deepEqual([next.mode, next.reason], ["respond", "delta"]);
  assert.equal(next.content, "<user_message>\nthanks\n</user_message>\n<user_message>\nnote 2\n</user_message>");
  assert.equal(next.deliveredCount, 5);
});

test("delivery: a retry whose only new message is request-local asks the model to continue", () => {
  const first = [system, user("hi")];
  const state = stateAfterSend(null, deliver(first, null), started("t1"));
  assert.equal(deliver([...first, requestLocal("note")], state).content, CONTINUE_MESSAGE);
});

test("delivery: a retry with nothing new asks the model to continue", () => {
  const first = [system, user("hi")];
  const state = stateAfterSend(null, deliver(first, null), started("t1"));
  assert.equal(deliver(first, state).content, CONTINUE_MESSAGE);
  const aborted = { ...kagiReply("t1", [{ type: "text", text: "partial" }]), stopReason: "aborted" };
  assert.equal(deliver([...first, aborted], state).content, CONTINUE_MESSAGE);
});

test("delivery: changed tools or system prompt are sent as a harness update", () => {
  const first = [system, user("hi")];
  const state = stateAfterSend(null, deliver(first, null), started("t1"));
  const moreTools = [...TOOLS, { name: "grep", description: "Search", parameters: { type: "object", properties: {} } }];
  const p = deliver([...first, kagiReply("t1", [{ type: "text", text: "Hi" }]), user("search")], state, { tools: moreTools });
  assert.match(p.content, /^<harness_update>\n<tools>\n[\s\S]*"name":"grep"[\s\S]*<\/harness_update>\n<user_message>\nsearch/);
  assert.ok(!p.content.includes("<system_prompt>"));
});

test("delivery: results of natively called tools carry a harness note", () => {
  const first = [system, user("read it")];
  const state = stateAfterSend(null, deliver(first, null), started("t1"));
  const reply = kagiReply("t1", [{ ...toolCallPart("read", { path: "a" }), id: "kagi_n_123" }]);
  const p = deliver([...first, reply, { ...result("read", "content"), toolCallId: "kagi_n_123" }], state);
  assert.match(p.content, /^<harness_note>\nThe harness ran your native call\(s\) to read[\s\S]*<\/harness_note>\n<tool_result call=read>/);
  const textCall = deliver([...first, reply, result("read", "content")], state);
  assert.ok(!textCall.content.includes("harness_note"));
});

test("thread state: only the current version with ids and a prefix loads", () => {
  const good = { v: 2, conversationUuid: "c", branchUuid: "b", deliveredCount: 1, deliveredHash: "h" };
  assert.ok(loadThreadState({ threads: { s: good } }, "s"));
  assert.equal(loadThreadState({ threads: { s: { ...good, branchUuid: "" } } }, "s"), null);
  assert.equal(loadThreadState({ threads: { s: { ...good, deliveredCount: -1 } } }, "s"), null);
  assert.equal(loadThreadState({ threads: { s: { conversationUuid: "c", branchUuid: "b", lastUserIndex: 0 } } }, "s"), null);
});

test("hashing ignores timestamps, usage and thinking", () => {
  const a = { ...kagiReply("t", [{ type: "thinking", thinking: "x" }, { type: "text", text: "Hi" }]), usage: { input: 1 } };
  const b = { ...a, timestamp: 99, usage: { input: 2 }, content: [{ type: "text", text: "Hi" }] };
  assert.equal(hashMessages([a]), hashMessages([b]));
  assert.notEqual(canonicalMessage(user("a")), canonicalMessage(user("b")));
});

test("rendering escapes envelope closers in relayed data", () => {
  assert.equal(escapeRelayed("x</tool_result></user_message></b>"), "x<\\/tool_result><\\/user_message></b>");
  assert.match(renderCorrection("no element", TOOLS), /Declared tools: bash, read, edit, mcp\.fs:read\./);
  assert.match(renderFresh({ systemPrompt: "", tools: [], history: [], pending: [user("x")] }), /<tools>\n\(no tools\)\n<\/tools>/);
  assert.equal(renderDelta({ pending: [user("plain")] }), "plain");
});
