import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { type Component, Container, getKeybindings, Text } from "@earendil-works/pi-tui";
import { homedir } from "node:os";

/** Live input preview for context-mode execution tools, styled like the built-in bash tool:
 * bold title with a muted `(timeout …, …)` suffix, a 5-visual-line collapsed body with an expand
 * hint, and an `Elapsed`/`Took` timer under the result. Execution is never approval-gated.
 * Esc cancellation is provided by pi/patches/context-mode-cancellation.mjs, not by this renderer.
 */
const TOOLS = new Set(["ctx_execute", "ctx_execute_file", "ctx_batch_execute"]);
/** Same budget the bash renderer uses for its collapsed output. */
export const PREVIEW_LINES = 5;
/** Keys rendered in the title/body; everything else is listed as a muted `key: value` line. */
const SHOWN_KEYS = new Set(["code", "commands", "cwd", "timeout", "background", "concurrency", "language", "path"]);

type Theme = { fg: (color: any, text: string) => string; bold: (text: string) => string };
type Input = Record<string, unknown>;

export function isExecutionTool(name: string): boolean {
  return TOOLS.has(name);
}

/** Render literal controls visibly; never allow submitted code to emit terminal control sequences. */
export function literal(text: string): string {
  return text.replace(/\t/g, "    ").replace(/[\x00-\x09\x0b-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]/g,
    (char) => `\\u${char.charCodeAt(0).toString(16).padStart(4, "0")}`);
}

/** Same shape as bash's duration format: `1.5s`, `2m 5s`, `1h 2m 3s`. */
export function formatDuration(ms: number): string {
  const seconds = ms / 1000;
  if (seconds < 60) return `${Number.isInteger(seconds) ? seconds : seconds.toFixed(1)}s`;
  const total = Math.floor(seconds), minutes = Math.floor(total / 60), rest = total % 60;
  if (minutes < 60) return rest ? `${minutes}m ${rest}s` : `${minutes}m`;
  return `${Math.floor(minutes / 60)}h ${minutes % 60}m ${rest}s`;
}

const stringify = (value: unknown) => typeof value === "string" ? value : JSON.stringify(value) ?? String(value);
const shortenPath = (path: string) => {
  const home = homedir();
  return home && (path === home || path.startsWith(`${home}/`)) ? `~${path.slice(home.length)}` : path;
};

export interface CallView {
  /** Styled title line, e.g. `ctx_execute python (timeout 30s, cwd ~/repo)`. */
  title: string;
  /** Styled muted lines (intent, queries, unknown options). */
  meta: string[];
  /** Styled body (code or batch commands); subject to the collapsed line budget. */
  body: string;
}

export function formatCall(name: string, input: Input, sessionCwd: string, theme: Theme, opts: { expanded: boolean; argsComplete: boolean }): CallView {
  const muted = (text: string) => theme.fg("muted", text);
  const out = (text: string) => theme.fg("toolOutput", text);
  const titleParts = [theme.fg("toolTitle", theme.bold(name))];
  if (typeof input.language === "string") titleParts.push(theme.fg("accent", literal(input.language)));
  if (name === "ctx_execute_file") {
    titleParts.push(typeof input.path === "string" ? theme.fg("accent", literal(shortenPath(input.path))) : out("..."));
  }
  if (name === "ctx_batch_execute" && Array.isArray(input.commands)) {
    titleParts.push(muted(`${input.commands.length} command${input.commands.length === 1 ? "" : "s"}`));
  }

  const suffix: string[] = [];
  if (input.timeout !== undefined) {
    suffix.push(`timeout ${typeof input.timeout === "number" ? formatDuration(input.timeout) : literal(stringify(input.timeout))}`);
  }
  if (input.background === true) suffix.push("background");
  if (input.concurrency !== undefined && input.concurrency !== 1) suffix.push(`concurrency ${literal(stringify(input.concurrency))}`);
  if (typeof input.cwd === "string") suffix.push(`cwd ${literal(shortenPath(input.cwd))}`);
  if (!opts.argsComplete) suffix.push("receiving arguments…");
  const title = titleParts.join(" ") + (suffix.length ? muted(` (${suffix.join(", ")})`) : "");

  const meta: string[] = [];
  // The MCP server owns the default cwd, which need not equal the pi cwd after a session switch.
  if (opts.expanded && typeof input.cwd !== "string") meta.push(muted(`cwd: server default (pi session: ${literal(shortenPath(sessionCwd))})`));
  for (const [key, value] of Object.entries(input)) {
    if (SHOWN_KEYS.has(key) || value === undefined) continue;
    const shown = Array.isArray(value) && value.every(v => typeof v === "string") ? value.join(" · ") : stringify(value);
    meta.push(muted(`${key}: ${literal(shown)}`));
  }

  let body = "";
  if (typeof input.code === "string") {
    const code = literal(input.code);
    body = out(input.language === "shell" ? `$ ${code}` : code);
  } else if (Array.isArray(input.commands)) {
    body = input.commands.map((command) => {
      const c = command as { label?: unknown; command?: unknown } | null;
      const label = c?.label === undefined ? "" : muted(`# ${literal(stringify(c.label))}`) + "\n";
      return label + out(`$ ${literal(c?.command === undefined ? stringify(command) : stringify(c.command))}`);
    }).join("\n");
  } else if (!opts.argsComplete) {
    body = out("...");
  }
  return { title, meta, body };
}

function expandKey(): string {
  try {
    return getKeybindings().getKeys("app.tools.expand").join("/") || "ctrl+o";
  } catch {
    return "ctrl+o";
  }
}

/** Title + meta always visible; body clipped to visual lines (wrapping-aware) like bash output. */
export class CallComponent implements Component {
  private view: CallView = { title: "", meta: [], body: "" };
  private expanded = false;
  private theme: Theme | undefined;
  private head = new Text("", 0, 0);
  private bodyText = new Text("", 0, 0);

  set(view: CallView, expanded: boolean, theme: Theme): void {
    this.view = view;
    this.expanded = expanded;
    this.theme = theme;
    this.head.setText([view.title, ...view.meta].join("\n"));
    this.bodyText.setText(view.body);
  }

  render(width: number): string[] {
    const lines = this.head.render(width);
    if (!this.view.body) return lines;
    const body = this.bodyText.render(width);
    if (this.expanded || body.length <= PREVIEW_LINES) return [...lines, ...body];
    const hidden = body.length - PREVIEW_LINES;
    const t = this.theme!;
    const hint = t.fg("muted", `... (${hidden} more line${hidden === 1 ? "" : "s"}, `)
      + t.fg("dim", expandKey()) + t.fg("muted", " to expand)");
    return [...lines, ...body.slice(0, PREVIEW_LINES), ...new Text(hint, 0, 0).render(width)];
  }

  invalidate(): void {
    this.head.invalidate();
    this.bodyText.invalidate();
  }
}

interface RowState {
  startedAt?: number;
  endedAt?: number;
  interval?: ReturnType<typeof setInterval>;
  inner?: Component;
}

export default function (pi: ExtensionAPI) {
  // Clear any footer left by the removed approval-gate version on reload.
  pi.on("session_start", (_event, ctx) => {
    if (ctx.hasUI) ctx.ui.setStatus("ctx-approval", undefined);
  });
  pi.registerToolRenderer((name, next) => {
    if (!isExecutionTool(name)) return undefined;
    const base = next();
    const renderers: Record<string, unknown> = {
      ...base, // Preserve context-mode's execution semantics and result rendering.
      renderCall(args: unknown, theme: Theme, context: any) {
        const state = (context.state ?? {}) as RowState;
        // Like bash: start the clock only for live executions (not when replaying a session).
        if (context.executionStarted && state.startedAt === undefined) {
          state.startedAt = Date.now();
          state.endedAt = undefined;
        }
        const input = args && typeof args === "object" ? args as Input : {};
        const view = formatCall(name, input, context.cwd, theme, {
          expanded: !!context.expanded, argsComplete: context.argsComplete !== false,
        });
        const component = context.lastComponent instanceof CallComponent ? context.lastComponent : new CallComponent();
        component.set(view, !!context.expanded, theme);
        return component;
      },
    };
    const baseResult = (base as any)?.renderResult;
    if (typeof baseResult === "function") {
      renderers.renderResult = (result: unknown, options: { expanded: boolean; isPartial: boolean }, theme: Theme, context: any) => {
        const state = (context.state ?? {}) as RowState;
        const inner = baseResult(result, options, theme, { ...context, lastComponent: state.inner }) as Component;
        state.inner = inner;
        if (state.startedAt !== undefined && options.isPartial && !state.interval) {
          state.interval = setInterval(() => context.invalidate(), 1000);
        }
        if (!options.isPartial || context.isError) {
          state.endedAt ??= Date.now();
          if (state.interval) {
            clearInterval(state.interval);
            state.interval = undefined;
          }
        }
        const container = context.lastComponent instanceof Container ? context.lastComponent : new Container();
        container.clear();
        if (inner) container.addChild(inner);
        if (state.startedAt !== undefined) {
          const label = options.isPartial ? "Elapsed" : "Took";
          const elapsed = (state.endedAt ?? Date.now()) - state.startedAt;
          container.addChild(new Text(`\n${theme.fg("muted", `${label} ${formatDuration(elapsed)}`)}`, 0, 0));
        }
        container.invalidate();
        return container;
      };
    }
    return renderers as any;
  });
}
