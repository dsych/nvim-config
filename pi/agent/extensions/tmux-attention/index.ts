import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFile } from "node:child_process";

/**
 * tmux-attention
 *
 * Tells tmux when this pi needs you, so the tmux session picker (prefix s) can mark that session:
 *   ?  pi is asking you something (an extension dialog, e.g. a confirmation)
 *   @  a run has ended (finished, stopped or failed): your turn
 * Only what you haven't seen: if a focused terminal shows pi's window at that moment, nothing is
 * marked, and tmux clears a mark when you arrive at the window (a pane-focus-in hook in tmux.conf).
 *
 * Separately, it tells tmux where work is happening, shown as ~ next to windows and sessions:
 *   @pi-working          when the current run started (epoch seconds); set while a run is
 *                        active, whether or not you're looking. Not set while pi is blocked on a
 *                        dialog: that's ? (waiting for you), not work.
 *
 * The state lives in user options on pi's own pane ($TMUX_PANE, which tmux sets for every process
 * in a pane), read by the picker:
 *   @pi-attention        "ask" or "done"; unset while nothing waits for you
 *   @pi-attention-since  when it was set (epoch seconds): the picker goes to the oldest
 *   @pi-attention-pid    this pi's process id, so the picker skips a pi that died without
 *                        cleaning up (SIGKILL)
 *
 * Interactive pi only: `pi -p` subagents and swarm agents inherit the same $TMUX_PANE and would
 * mark their parent's pane. Each change is one tmux command; they run in order, and failures
 * (no tmux server, tmux not on PATH) are ignored.
 */

/** Runs `tmux <args>`; resolves when it has finished, whatever the outcome. */
export type TmuxRunner = (args: string[]) => Promise<void>;

const runTmux: TmuxRunner = (args) =>
  new Promise((resolve) => {
    execFile("tmux", args, { timeout: 2000, windowsHide: true }, () => resolve());
  });

/**
 * True (for the pane the command targets) when you can see it: a client attached to the pane's
 * session has a focused terminal, the pane's window is the session's current window, and the
 * pane isn't hidden behind another zoomed pane. The same rule tmux uses for pane focus events.
 */
export const LOOKING =
  "#{&&:#{L:#{?#{&&:#{==:#{client_session},#{session_name}},#{m:*focused*,#{client_flags}}},1,}}," +
  "#{&&:#{window_active},#{||:#{!:#{window_zoomed_flag}},#{pane_active}}}}";

export function tmuxAttention(run: TmuxRunner = runTmux, env: NodeJS.ProcessEnv = process.env) {
  return function (pi: ExtensionAPI) {
    const pane = env.TMUX ? env.TMUX_PANE : undefined;
    if (!pane) return;

    // One at a time, in order: a fast run must not apply its start after its end
    let queue = Promise.resolve();
    const tmux = (...args: string[]) => (queue = queue.then(() => run(args)).catch(() => {}));
    const set = (option: string, value: string) => `set-option -p -t ${pane} ${option} ${value}`;
    const unset = (option: string) => `set-option -p -t ${pane} -u ${option}`;

    let active = false;
    let running = false;     // between agent_start and agent_settled
    let prompting = false;   // a blocking dialog is open
    let runSince = "";
    const now = () => String(Math.floor(Date.now() / 1000));
    const opt = (...args: string[]) => ["set-option", "-p", "-t", pane, ...args];
    // The working mark as one command (joined with ; into the same tmux call as the attention
    // change, so the status line never shows an in-between state)
    const working = (): string[] =>
      running && !prompting ? opt("@pi-working", runSince) : opt("-u", "@pi-working");
    const clear = () => active && tmux(...opt("-u", "@pi-attention"), ";", ...working());
    // Mark unless you're looking (then also drop an older mark): decided by tmux, in one command
    const mark = (state: "ask" | "done") =>
      active &&
      tmux(
        ...working(), ";",
        "if-shell", "-F", "-t", pane, LOOKING,
        unset("@pi-attention"),
        `${set("@pi-attention", state)} ; ${set("@pi-attention-since", now())}`,
      );

    pi.on("session_start", async (_event, ctx) => {
      active = ctx.mode === "tui";
      running = prompting = false;
      if (active) await tmux(...opt("-u", "@pi-attention"), ";", ...opt("-u", "@pi-working"), ";",
        ...opt("@pi-attention-pid", String(process.pid)));
    });
    pi.on("agent_start", () => {
      if (!running) runSince = now();   // a retry or continuation keeps the run's start time
      running = true;
      clear();
    });
    pi.on("ui_prompt_start", () => { prompting = true; mark("ask"); });
    pi.on("ui_prompt_end", () => { prompting = false; clear(); });
    pi.on("agent_settled", () => { running = false; mark("done"); });
    pi.on("session_shutdown", async () => {
      if (!active) return;
      active = false;
      running = prompting = false;
      await tmux(...opt("-u", "@pi-attention"), ";", ...opt("-u", "@pi-attention-since"), ";",
        ...opt("-u", "@pi-working"), ";", ...opt("-u", "@pi-attention-pid"));
    });
  };
}

export default tmuxAttention();
