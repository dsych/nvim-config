// PI_PACKAGE_ROOT=/path/to/@earendil-works/pi-coding-agent node --test pi/tests/kagi-assistant-stream.test.mjs
// End-to-end tests of the Kagi provider through pi's real stream types, against
// a scripted fake Kagi server. No network, temporary HOME.
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createRequire } from "node:module";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

const root = process.env.PI_PACKAGE_ROOT;
assert.ok(root, "Set PI_PACKAGE_ROOT");
const requirePi = createRequire(join(root, "package.json"));
const { createJiti } = requirePi("jiti");
const aiPath = join(root, "node_modules/@earendil-works/pi-ai/dist/index.js");
const jiti = createJiti(import.meta.url, { alias: { "@earendil-works/pi-ai": aiPath } });
const ai = await jiti.import(aiPath);

const HOME = fs.mkdtempSync(path.join(os.tmpdir(), "kagi-e2e-"));
process.env.HOME = HOME;
process.env.KAGI_SESSION_TOKEN = "test-token";
delete process.env.KAGI_DEBUG;

// ---------------------------------------------------------------------------
// Fake Kagi Assistant server
// ---------------------------------------------------------------------------

const server = {
  requests: [],
  replies: [], // queued scripted replies, one per assistant turn
  turns: new Map(), // turnUuid -> {reply, status, cost}
  profiles: [],
  branchConversation: new Map(),
  failNext: [], // [{match: (method, path) => bool, status, body}]
  seq: 0,
  reset() {
    this.requests = [];
    this.replies = [];
    this.failNext = [];
  },
};

function sse(turnUuid, reply) {
  const frames = [];
  const ev = (type, node_id, payload) => frames.push(`data: ${JSON.stringify({ event: { turn_id: turnUuid, type, node_id, payload } })}\n\n`);
  ev("turn.started", null, { root_node_id: "msg_1" });
  ev("node.created", "msg_1", { kind: "assistant_message" });
  ev("node.created", "config_1", { kind: "activity", type: "config", settings: {} });
  for (let i = 0; i < (reply.emptyThinking ?? 0); i++) {
    ev("node.created", `thinking_e${i}`, { kind: "activity", type: "thinking", step: 1 });
    ev("node.completed", `thinking_e${i}`, { status: "completed" });
  }
  if (reply.thinking) {
    ev("node.created", "thinking_1", { kind: "activity", type: "thinking", content: reply.thinking.slice(0, 3), step: 1 });
    ev("node.delta", "thinking_1", { delta: reply.thinking.slice(3) });
    ev("node.completed", "thinking_1", { content: reply.thinking });
  }
  for (const [i, call] of (reply.native ?? []).entries()) {
    const id = `toolu_${i}`;
    ev("node.created", id, { kind: "activity", type: "tool_call", tool_name: call.name, arguments_partial: null, step: 1 });
    ev("node.updated", id, { status: "running", tool_name: call.name, arguments: call.arguments });
    ev("node.completed", id, { status: "completed", result: { content: `Unknown tool name: '${call.name}'.` }, arguments: call.arguments, tool_error: true });
  }
  if (reply.text) {
    ev("node.created", "text_1", { kind: "text", step: reply.native ? 2 : 1 });
    for (let i = 0; i < reply.text.length; i += 7) ev("node.delta", "text_1", { delta: reply.text.slice(i, i + 7) });
    if (reply.cut) return frames.join("");
    ev("node.completed", "text_1", { content: reply.text });
  }
  if (reply.fail) {
    ev("turn.failed", null, { error_code: reply.fail });
    return frames.join("");
  }
  ev("turn.completed", null, { usage: { input_tokens: 3000, output_tokens: 20, cache_read_tokens: 1000, cache_write_tokens: 0, cost_usd: reply.cost ?? 0.001 } });
  frames.push(`data: ${JSON.stringify({ is_final: true, billing: { usage: { included_cost_usd: 1, included_cost_limit_usd: 100 } } })}\n\n`);
  return frames.join("");
}

function json(status, body) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

function startTurn(conversation, branch) {
  const turnUuid = `turn-${++server.seq}`;
  const reply = server.replies.shift() ?? { text: "default reply" };
  server.turns.set(turnUuid, { reply, status: reply.running ? "running" : "completed", cost: reply.cost ?? 0.001 });
  server.branchConversation.set(branch, conversation);
  return { conversation_uuid: conversation, branch_uuid: branch, assistant_turn_uuid: turnUuid, user_turn_uuid: `u-${server.seq}` };
}

globalThis.fetch = async (url, init = {}) => {
  const u = new URL(url);
  const method = init.method ?? "GET";
  const body = init.body ? JSON.parse(init.body) : undefined;
  server.requests.push({ method, path: u.pathname, body, headers: init.headers });
  const fail = server.failNext.findIndex((f) => f.match(method, u.pathname));
  if (fail !== -1) {
    const [f] = server.failNext.splice(fail, 1);
    return json(f.status, f.body);
  }
  if (u.pathname === "/api/init") {
    return json(200, {
      has_unlimited_access: false,
      models: {
        models: [
          { id: "deepseek-v4-1-flash", display_name: "DeepSeek", context_window: 1048576, parameters: { reasoning_effort: { options: ["none", "low", "high", "max"] } } },
          { id: "claude-5-5-opus", access_level: "unlimited", parameters: { reasoning_effort: { options: ["low"] } } },
        ],
      },
    });
  }
  if (u.pathname === "/api/assistants" && method === "GET") return json(200, server.profiles);
  if (u.pathname === "/api/assistants" && method === "POST") {
    const p = { ...body, uuid: `profile-${++server.seq}` };
    server.profiles.push(p);
    return json(201, p);
  }
  if (u.pathname.startsWith("/api/assistants/") && method === "PATCH") {
    const p = server.profiles.find((x) => x.uuid === u.pathname.split("/").pop());
    Object.assign(p, body);
    return json(200, p);
  }
  if (u.pathname === "/api/v2/conversations") return json(200, startTurn(`conv-${++server.seq}`, `branch-${server.seq}`));
  const respond = /^\/api\/v2\/branches\/([^/]+)\/respond$/.exec(u.pathname);
  if (respond) return json(200, startTurn(server.branchConversation.get(respond[1]), respond[1]));
  const stream = /^\/api\/v2\/turns\/([^/]+)\/stream$/.exec(u.pathname);
  if (stream) {
    const t = server.turns.get(stream[1]);
    return new Response(sse(stream[1], t.reply), { status: 200, headers: { "content-type": "text/event-stream" } });
  }
  const turn = /^\/api\/v2\/turns\/([^/]+)$/.exec(u.pathname);
  const cancel = /^\/api\/v2\/turns\/([^/]+)\/cancel$/.exec(u.pathname);
  if (cancel) {
    server.turns.get(cancel[1]).status = "cancelled";
    return new Response(null, { status: 204 });
  }
  if (turn) {
    const t = server.turns.get(turn[1]);
    const status = t.status;
    if (status === "running") t.status = "completed"; // running once, then done
    return json(200, { uuid: turn[1], status, cost_usd: status === "cancelled" ? null : t.cost });
  }
  return json(404, { error: { code: "not_found", message: "Not found" } });
};

// ---------------------------------------------------------------------------
// Load the extension with a minimal pi API
// ---------------------------------------------------------------------------

const registered = { providers: new Map(), handlers: new Map(), commands: new Map() };
const notifications = [];
const extensionPath = fileURLToPath(new URL("../agent/extensions/kagi-assistant/index.ts", import.meta.url));
const { default: extension } = await jiti.import(extensionPath);
await extension({
  registerProvider: (name, config) => registered.providers.set(name, config),
  on: (event, handler) => registered.handlers.set(event, handler),
  registerCommand: (name, command) => registered.commands.set(name, command),
});
const provider = registered.providers.get("kagi");
const model = { ...provider.models[0], provider: "kagi", baseUrl: provider.baseUrl };
await registered.handlers.get("session_start")({}, { ui: { notify: (m, l) => notifications.push([l, m]) }, sessionManager: { getEntries: () => [] } });

const TOOLS = [
  { name: "bash", description: "Run a command", parameters: { type: "object", properties: { command: { type: "string" } }, required: ["command"] } },
  { name: "read", description: "Read a file", parameters: { type: "object", properties: { path: { type: "string" } }, required: ["path"] } },
];
const SYSTEM = "You are pi. Working directory: /project.";
const user = (text) => ({ role: "user", content: text, timestamp: Date.now() });

async function call(messages, { sessionId = "s1", tools = TOOLS, ...options } = {}) {
  const context = ai.normalizeContext({ systemPrompt: SYSTEM, tools, messages });
  const events = [];
  const stream = provider.streamSimple(model, context, { sessionId, ...options });
  for await (const ev of stream) events.push(ev);
  return { events, message: await stream.result() };
}

const types = (events) => events.map((e) => e.type);
const sent = (pathRe) => server.requests.filter((r) => pathRe.test(r.path) && r.method === "POST");
const savedThread = (sessionId) => JSON.parse(fs.readFileSync(path.join(HOME, ".pi/kagi.json"), "utf8")).threads[sessionId];

// ---------------------------------------------------------------------------

test("registration: catalog models the account can use, thinking levels mapped", () => {
  assert.deepEqual(provider.models.map((m) => m.id), ["deepseek-v4-1-flash"]);
  assert.equal(provider.api, "kagi-assistant");
  assert.equal(provider.models[0].thinkingLevelMap.off, "none");
});

test("first message: profile created, harness init carries pi's system prompt and tools", async () => {
  server.reset();
  server.replies.push({ text: "Hello from Kagi.", thinking: "Greet the user." });
  const { events, message } = await call([user("hi")], { reasoning: "high" });
  assert.deepEqual(types(events), ["start", "thinking_start", "thinking_delta", "thinking_delta", "thinking_end", "text_start", "text_delta", "text_delta", "text_delta", "text_end", "done"]);
  assert.equal(message.stopReason, "stop");
  assert.equal(message.content.at(-1).text, "Hello from Kagi.");
  assert.equal(message.content[0].thinking, "Greet the user.");
  assert.equal(message.usage.cost.total, 0.001);
  assert.deepEqual([message.usage.input, message.usage.cacheRead, message.usage.totalTokens], [2000, 1000, 3020]);
  const [profile] = server.profiles;
  assert.equal(profile.name, "pi-harness-deepseek-v4-1-flash");
  assert.match(profile.instructions, /<function_calls>/);
  const [start] = sent(/conversations$/);
  assert.equal(start.body.profile_uuid, profile.uuid);
  assert.equal(start.body.reasoning_effort, "high");
  assert.equal(start.body.enable_search, false);
  assert.match(start.body.content, /<system_prompt>\nYou are pi\. Working directory: \/project\.\n<\/system_prompt>/);
  assert.match(start.body.content, /"name":"bash"/);
  assert.equal(message.responseId, "turn-" + server.seq);
  assert.equal(savedThread("s1").lastTurn.settled, true);
});

test("tool call: markup is never streamed; prose stays; calls become pi tool calls", async () => {
  server.reset();
  const history = [user("list files")];
  server.replies.push({ text: "I'll list them.\n\n<function_calls>\n<function=bash>\n<parameter=command>ls -la</parameter>\n</function>\n</function_calls>" });
  const { events, message } = await call(history, { sessionId: "s2" });
  const streamedText = events.filter((e) => e.type === "text_delta").map((e) => e.delta).join("");
  assert.ok(!streamedText.includes("<function"), streamedText);
  assert.equal(message.stopReason, "toolUse");
  assert.deepEqual(message.content.map((c) => c.type), ["text", "toolCall"]);
  assert.equal(message.content[0].text, "I'll list them.");
  assert.deepEqual([message.content[1].name, message.content[1].arguments], ["bash", { command: "ls -la" }]);
  assert.ok(types(events).includes("toolcall_end"));

  // pi runs the tool and calls again: only the result is sent, not our own reply.
  server.replies.push({ text: "There are two files." });
  const toolResult = { role: "toolResult", toolCallId: message.content[1].id, toolName: "bash", content: [{ type: "text", text: "a.txt\nb.txt" }], isError: false, timestamp: Date.now() };
  const second = await call([...history, message, toolResult], { sessionId: "s2" });
  assert.equal(second.message.stopReason, "stop");
  const [respond] = sent(/respond$/);
  assert.equal(respond.body.content, "<tool_result call=bash>\na.txt\nb.txt\n</tool_result>");
});

test("an unrunnable tool block gets one correction in the same conversation", async () => {
  server.reset();
  server.replies.push(
    { text: "<function_calls>\n<function=list_directory>\n<parameter=path>.</parameter>\n</function>\n</function_calls>", cost: 0.002 },
    { text: "<function_calls>\n<function=bash>\n<parameter=command>ls</parameter>\n</function>\n</function_calls>", cost: 0.003 },
  );
  const { message } = await call([user("what is here?")], { sessionId: "s3" });
  assert.equal(message.stopReason, "toolUse");
  assert.equal(message.content.filter((c) => c.type === "toolCall")[0].name, "bash");
  assert.ok(!message.content.some((c) => c.type === "text" && c.text.includes("list_directory")));
  const [correction] = sent(/respond$/);
  assert.match(correction.body.content, /<harness_error>[\s\S]*list_directory[\s\S]*Declared tools: bash, read\./);
  assert.ok(Math.abs(message.usage.cost.total - 0.005) < 1e-9);
});

test("abort: the running turn is cancelled on Kagi; the next send does not wait for it", async () => {
  server.reset();
  server.replies.push({ text: "Counting 1 2 3 4 5 6 7 8 9 10", cut: true, running: true, cost: 0.004 });
  const controller = new AbortController();
  const context = ai.normalizeContext({ systemPrompt: SYSTEM, tools: TOOLS, messages: [user("count")] });
  const stream = provider.streamSimple(model, context, { sessionId: "s4", signal: controller.signal });
  for await (const ev of stream) if (ev.type === "text_delta") controller.abort();
  const aborted = await stream.result();
  assert.equal(aborted.stopReason, "aborted");
  await new Promise((r) => setTimeout(r, 50));
  assert.equal(server.requests.filter((r) => r.path.endsWith("/cancel")).length, 1);
  assert.equal(savedThread("s4").lastTurn.settled, false);

  server.replies.push({ text: "Okay." });
  const { message } = await call([user("count"), aborted, user("stop, say okay")], { sessionId: "s4" });
  const polls = server.requests.filter((r) => /^\/api\/v2\/turns\/[^/]+$/.test(r.path));
  assert.equal(polls.length, 1); // cancelled is final: no waiting
  assert.ok(Math.abs(message.usage.cost.total - 0.001) < 1e-9); // a cancelled turn reports no cost
  assert.equal(sent(/respond$/)[0].body.content, "stop, say okay");
});

test("an unfinished turn (stream cut, not aborted) is waited for and its cost collected", async () => {
  server.reset();
  server.replies.push({ text: "Long answer", cut: true, running: true, cost: 0.004 });
  const first = await call([user("long")], { sessionId: "s4b" });
  assert.equal(first.message.stopReason, "error");
  server.replies.push({ text: "Done." });
  const { message } = await call([user("long"), user("again")], { sessionId: "s4b" });
  assert.equal(server.requests.filter((r) => /^\/api\/v2\/turns\/[^/]+$/.test(r.path)).length, 2); // running, then completed
  assert.ok(Math.abs(message.usage.cost.total - 0.005) < 1e-9);
});

test("a declared tool called natively becomes a pi tool call; the rest of the turn is cancelled", async () => {
  server.reset();
  server.replies.push({ native: [{ name: "read", arguments: { path: "calc.py" } }, { name: "read_file", arguments: { path: "calc.py" } }], text: "I cannot read files here." });
  const { events, message } = await call([user("show calc.py")], { sessionId: "s11" });
  assert.equal(message.stopReason, "toolUse");
  assert.deepEqual(message.content.filter((c) => c.type === "toolCall").map((c) => [c.name, c.arguments]), [["read", { path: "calc.py" }]]);
  assert.ok(!events.some((e) => e.type === "text_delta"));
  await new Promise((r) => setTimeout(r, 50));
  assert.equal(server.requests.filter((r) => r.path.endsWith("/cancel")).length, 1);
});

test("built-in Kagi file tools: their text is held back and a correction names them", async () => {
  server.reset();
  server.replies.push(
    { native: [{ name: "list_directory", arguments: { path: "." } }], text: "The directory looks empty." },
    { text: "<function_calls>\n<function=bash>\n<parameter=command>ls</parameter>\n</function>\n</function_calls>" },
  );
  const { events, message } = await call([user("what files are here?")], { sessionId: "s12" });
  assert.equal(message.stopReason, "toolUse");
  assert.ok(!events.some((e) => e.type === "text_delta" && e.delta.includes("looks empty")));
  assert.ok(!message.content.some((c) => c.type === "text" && c.text.includes("looks empty")));
  assert.equal(server.requests.filter((r) => r.path.endsWith("/cancel")).length, 0);
  const [correction] = sent(/respond$/);
  assert.match(correction.body.content, /built-in Kagi tools \(list_directory\)\. They run on a remote server/);
});

test("a deleted profile is recreated and the message resent once", async () => {
  server.reset();
  server.failNext.push({ match: (m, p) => m === "POST" && p === "/api/v2/conversations", status: 404, body: { error: { code: "not_found", message: "Custom assistant not found" } } });
  server.profiles.length = 0; // deleted on Kagi as well
  server.replies.push({ text: "Recovered." });
  const { message } = await call([user("hello again")], { sessionId: "s5" });
  assert.equal(message.stopReason, "stop");
  assert.equal(server.profiles.length, 1);
  assert.equal(sent(/conversations$/).length, 2);
});

test("an expired conversation restarts with the full transcript", async () => {
  server.reset();
  server.replies.push({ text: "First answer." });
  const first = await call([user("question one")], { sessionId: "s6" });
  server.failNext.push({ match: (m, p) => m === "POST" && /respond$/.test(p), status: 404, body: { error: { code: "not_found", message: "Branch not found" } } });
  server.replies.push({ text: "Second answer." });
  const { message } = await call([user("question one"), first.message, user("question two")], { sessionId: "s6" });
  assert.equal(message.content.at(-1).text, "Second answer.");
  const restart = sent(/conversations$/).at(-1);
  assert.match(restart.body.content, /<conversation_history>[\s\S]*question one[\s\S]*First answer\.[\s\S]*<\/conversation_history>\n<user_message>\nquestion two/);
  assert.ok(notifications.some(([, m]) => /expired/.test(m)));
});

test("a busy branch (409) waits for the previous turn and retries once", async () => {
  server.reset();
  server.replies.push({ text: "One." });
  const first = await call([user("one")], { sessionId: "s7" });
  server.failNext.push({ match: (m, p) => m === "POST" && /respond$/.test(p), status: 409, body: { error: { code: "request_state_changed", message: "The conversation changed" } } });
  server.replies.push({ text: "Two." });
  const { message } = await call([user("one"), first.message, user("two")], { sessionId: "s7" });
  assert.equal(message.content.at(-1).text, "Two.");
  assert.equal(sent(/respond$/).length, 2);
});

test("pi's request hooks: payload replacement, response observation, raw stream events", async () => {
  server.reset();
  server.replies.push({ text: "Hooked." });
  const seen = { responses: [], events: 0 };
  await call([user("hook")], {
    sessionId: "s8",
    onPayload: (payload) => ({ ...payload, content: payload.content + "\n(extra)" }),
    onResponse: (res) => seen.responses.push(res.status),
    onProviderStreamEvent: () => seen.events++,
  });
  assert.match(sent(/conversations$/)[0].body.content, /\(extra\)$/);
  assert.deepEqual(seen.responses, [200, 200]);
  assert.ok(seen.events >= 8);
});

test("a failed turn reports its error; without reported usage its cost is collected later", async () => {
  server.reset();
  server.replies.push({ text: "partial", fail: "model_error", cost: 0.002 });
  const { message } = await call([user("fail please")], { sessionId: "s9" });
  assert.equal(message.stopReason, "error");
  assert.match(message.errorMessage, /model_error/);
  assert.equal(savedThread("s9").lastTurn.settled, false);
  server.replies.push({ text: "Recovered." });
  const retry = await call([user("fail please")], { sessionId: "s9" });
  assert.ok(Math.abs(retry.message.usage.cost.total - 0.003) < 1e-9);
  assert.match(sent(/respond$/)[0].body.content, /did not reach the harness/);
});

test("the spend cap blocks before anything is sent", async () => {
  server.reset();
  await registered.commands.get("kagi-budget").handler("0.001", { ui: { notify: () => {} } });
  const { message } = await call([user("too expensive")], { sessionId: "s10" });
  assert.equal(message.stopReason, "error");
  assert.match(message.errorMessage, /cap reached/);
  assert.equal(server.requests.length, 0);
  await registered.commands.get("kagi-budget").handler("3", { ui: { notify: () => {} } });
});

test("a built-in web search before a plain answer is not corrected", async () => {
  server.reset();
  server.replies.push({ native: [{ name: "search", arguments: { query: "capital of France" } }], text: "Paris." });
  const { message } = await call([user("capital of France?")], { sessionId: "s13" });
  assert.equal(message.stopReason, "stop");
  assert.equal(message.content.at(-1).text, "Paris.");
  assert.equal(sent(/respond$/).length, 0);
});

test("empty thinking nodes (hidden reasoning) do not become empty blocks", async () => {
  server.reset();
  server.replies.push({ text: "Answer.", emptyThinking: 3 });
  const { message } = await call([user("think quietly")], { sessionId: "s14" });
  assert.deepEqual(message.content.map((c) => c.type), ["text"]);
});

test("a request-local message from another extension keeps the Kagi conversation", async () => {
  // context-mode's `context` hook appends a note to the first request of a run; pi passes it
  // without a timestamp, and the request after the tool call no longer contains it.
  server.reset();
  notifications.length = 0;
  const prompt = user("read hello.txt");
  const note = { role: "user", content: "context-mode active." };
  server.replies.push({ text: "<function_calls>\n<function=read>\n<parameter=path>hello.txt</parameter>\n</function>\n</function_calls>" });
  const first = await call([prompt, note], { sessionId: "s15" });
  assert.equal(first.message.stopReason, "toolUse");
  const [start] = sent(/conversations$/);
  assert.ok(!start.body.content.includes("<conversation_history>"));
  assert.match(start.body.content, /<user_message>\nread hello\.txt\n<\/user_message>\n<user_message>\ncontext-mode active\.\n<\/user_message>$/);

  server.replies.push({ text: "It says alpha." });
  const call1 = first.message.content.find((c) => c.type === "toolCall");
  const toolResult = { role: "toolResult", toolCallId: call1.id, toolName: "read", content: [{ type: "text", text: "alpha" }], isError: false, timestamp: Date.now() };
  const second = await call([prompt, first.message, toolResult], { sessionId: "s15" });
  assert.equal(second.message.content.at(-1).text, "It says alpha.");
  assert.equal(sent(/conversations$/).length, 1);
  assert.equal(sent(/respond$/)[0].body.content, "<tool_result call=read>\nalpha\n</tool_result>");
  assert.ok(!notifications.some(([, m]) => /history changed/.test(m)), JSON.stringify(notifications));
});
