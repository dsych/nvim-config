// PI_PACKAGE_ROOT=/path/to/@earendil-works/pi-coding-agent node --test pi/tests/ctx-inspect.test.mjs
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createRequire } from 'node:module';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = process.env.PI_PACKAGE_ROOT;
assert.ok(root, 'Set PI_PACKAGE_ROOT');
const requirePi = createRequire(join(root, 'package.json'));
const { createJiti } = requirePi('jiti');
const tuiPath = join(root, 'node_modules/@earendil-works/pi-tui/dist/index.js');
const jiti = createJiti(import.meta.url, { alias: { '@earendil-works/pi-tui': tuiPath } });
const { default: extension, formatCall, formatDuration, literal, PREVIEW_LINES } = await jiti.import(
  fileURLToPath(new URL('../agent/extensions/ctx-inspect/index.ts', import.meta.url)),
);
const { visibleWidth, Text } = await jiti.import(tuiPath);
const theme = { fg: (_color, text) => text, bold: text => text };
const ctx = (extra = {}) => ({ cwd: '/project', argsComplete: true, executionStarted: false, expanded: false, state: {}, ...extra });
const trim = (lines) => lines.map(l => l.trimEnd());
const plain = (view) => [view.title, ...view.meta, view.body].join('\n');

function harness() {
  let renderer;
  const handlers = new Map();
  extension({
    registerToolRenderer: resolve => { renderer = resolve; },
    on: (name, handler) => handlers.set(name, handler),
    registerCommand: () => assert.fail('No approval commands should be registered'),
    registerFlag: () => assert.fail('No approval flags should be registered'),
  });
  return { handlers, renderers: (name, next = () => undefined) => renderer(name, next) };
}

test('preview is always passive: no execution hooks, flags or approval commands', () => {
  const h = harness();
  assert.equal(h.handlers.has('tool_call'), false);
  const status = [];
  h.handlers.get('session_start')({}, { hasUI: true, ui: { setStatus: (...args) => status.push(args) } });
  assert.deepEqual(status, [['ctx-approval', undefined]]);
});

test('bash-like title: tool, language, muted (timeout, background, cwd) suffix; shell code gets $ prompt', () => {
  const r = harness().renderers('ctx_execute');
  const args = { language: 'shell', code: 'printf harmless', cwd: '/tmp', timeout: 30000, background: true };
  const snapshot = structuredClone(args);
  const lines = trim(r.renderCall(args, theme, ctx()).render(120));
  assert.equal(lines[0], 'ctx_execute shell (timeout 30s, background, cwd /tmp)');
  assert.equal(lines[1], '$ printf harmless');
  assert.deepEqual(args, snapshot);
  assert.equal(harness().renderers('bash'), undefined);
});

test('defaults are not noise: no suffix when nothing was requested; server-default cwd only when expanded', () => {
  const r = harness().renderers('ctx_execute');
  const collapsed = trim(r.renderCall({ language: 'python', code: 'print(1)' }, theme, ctx()).render(120));
  assert.deepEqual(collapsed, ['ctx_execute python', 'print(1)']);
  const expanded = r.renderCall({ language: 'python', code: 'print(1)' }, theme, ctx({ expanded: true })).render(120);
  assert.ok(expanded.some(l => l.includes('cwd: server default (pi session: /project)')));
});

test('collapsed body is limited to visual lines with an expand hint; expanded shows everything', () => {
  const r = harness().renderers('ctx_execute');
  const code = 'x'.repeat(4500) + '\nEND_OF_SCRIPT';
  const collapsed = r.renderCall({ code, language: 'python' }, theme, ctx());
  const out = trim(collapsed.render(100));
  assert.equal(out.length, 1 + PREVIEW_LINES + 1);
  assert.match(out.at(-1), /^\.\.\. \(\d+ more lines, ctrl\+o to expand\)$/);
  assert.doesNotMatch(out.join('\n'), /END_OF_SCRIPT/);
  const expanded = r.renderCall({ code, language: 'python' }, theme, ctx({ expanded: true, lastComponent: collapsed }));
  assert.equal(expanded, collapsed);
  assert.match(expanded.render(100).join('\n'), /END_OF_SCRIPT/);
  assert.ok((expanded.render(100).join('').match(/x/g) || []).length >= 4500);
});

test('batch and file previews include every command, label, path and option', () => {
  const batch = plain(formatCall('ctx_batch_execute', {
    commands: [{ label: 'one', command: 'printf one' }, { label: 'two', command: 'printf two' }],
    concurrency: 2, timeout: 90000, queries: ['errors', 'warnings'], cwd: '/repo',
  }, '/project', theme, { expanded: false, argsComplete: true }));
  for (const text of ['ctx_batch_execute 2 commands (timeout 1m 30s, concurrency 2, cwd /repo)',
    '# one\n$ printf one', '# two\n$ printf two', 'queries: errors · warnings']) assert.ok(batch.includes(text), text);
  const file = plain(formatCall('ctx_execute_file', { path: 'result.json', code: 'print(FILE_CONTENT)', language: 'python', intent: 'errors' },
    '/project', theme, { expanded: false, argsComplete: true }));
  for (const text of ['ctx_execute_file python result.json', 'print(FILE_CONTENT)', 'intent: errors']) assert.ok(file.includes(text), text);
});

test('streaming arguments are flagged in the title', () => {
  const view = formatCall('ctx_execute', {}, '/project', theme, { expanded: false, argsComplete: false });
  assert.equal(view.title, 'ctx_execute (receiving arguments…)');
});

test('durations match the bash format', () => {
  assert.equal(formatDuration(1500), '1.5s');
  assert.equal(formatDuration(30000), '30s');
  assert.equal(formatDuration(125000), '2m 5s');
  assert.equal(formatDuration(3723000), '1h 2m 3s');
});

test('result keeps context-mode rendering and adds Elapsed/Took only for live executions', () => {
  const calls = [], made = [];
  const renderResult = (result, options, _theme, context) => {
    calls.push(context.lastComponent);
    const text = new Text(options.isPartial ? 'indexing/searching...' : 'done', 0, 0);
    made.push(text);
    return text;
  };
  const r = harness().renderers('ctx_execute', () => ({ renderResult }));
  const state = {};
  r.renderCall({ code: 'x' }, theme, ctx({ executionStarted: true, state }));
  assert.ok(state.startedAt !== undefined);
  const partial = r.renderResult({}, { expanded: false, isPartial: true }, theme, ctx({ state, invalidate: () => {} }));
  assert.match(partial.render(80).join('\n'), /indexing\/searching\.\.\.[\s\S]*Elapsed \d/);
  assert.ok(state.interval, 'ticks while running');
  const done = r.renderResult({}, { expanded: false, isPartial: false }, theme, ctx({ state, lastComponent: partial }));
  assert.equal(done, partial);
  assert.match(done.render(80).join('\n'), /done[\s\S]*Took \d/);
  assert.equal(state.interval, undefined);
  assert.deepEqual([calls[0], calls[1]], [undefined, made[0]], 'inner lastComponent is threaded through');
  const replay = r.renderResult({}, { expanded: false, isPartial: false }, theme, ctx({ state: {} }));
  assert.doesNotMatch(replay.render(80).join('\n'), /Took|Elapsed/);
});

test('control characters are visible literals and wide text wraps inside terminal bounds', () => {
  const safe = literal('before\x1b[2Jafter\r\x07\u202e');
  assert.ok(safe.includes('\\u001b[2J'));
  assert.ok(!safe.includes('\x1b') && !safe.includes('\r') && !safe.includes('\u202e'));
  const r = harness().renderers('ctx_execute');
  const c = r.renderCall({ code: '中文 😀 '.repeat(50), cwd: '/a/\x1b[31m' }, theme, ctx({ expanded: true }));
  assert.ok(!c.render(120).join('').includes('\x1b[31m'));
  for (const width of [10, 40, 120]) for (const line of c.render(width)) assert.ok(visibleWidth(line) <= width);
});
