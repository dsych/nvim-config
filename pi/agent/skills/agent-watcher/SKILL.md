---
name: agent-watcher
description: Watch other pi agent panes in the current tmux window and automatically nudge them to continue when they halt (e.g. after a context compaction interrupt). Use when the user asks you to be a watcher/babysitter/monitor for other agents, keep agents running, auto-continue interrupted agents, or "make other pi agents continue their work". Auto-discovers sibling panes, distinguishes real pi agent panes from plain shell prompts, and only nudges genuine pi agents. Triggers on mentions of watcher agent, monitor panes, nudge agents, keep agents alive, auto-continue, or babysit agents.
---

# Agent Watcher

Act as a supervisor that keeps other pi agents running. The watcher discovers the
sibling panes in its own tmux window, figures out which of them are **pi agents** (vs
plain shells), monitors them on a fixed interval, and sends a "continue" prompt to any
agent that has halted (commonly after a context-compaction interrupt leaves it idle).

## When to use

Trigger when the user wants you to monitor/babysit other pi agents and auto-continue
them if they stop. Do **not** nudge plain shell panes, and do **not** nudge an agent
that has *deliberately* finished and is gated on a user decision (see Step 5).

## Step 1 — Locate yourself and your siblings

```bash
# Who am I and which window am I in
tmux display-message -p '#{session_name}:#{window_index} self=#{pane_id}'
# All panes in that window (replace main:1 with the window above)
tmux list-panes -t main:1 -F '#{pane_id} idx=#{pane_index} cmd=#{pane_current_command} active=#{pane_active}'
```

Your own pane id is in `$TMUX_PANE`. **Never watch or nudge your own pane.**

## Step 2 — Distinguish pi agents from shells (critical)

`pane_current_command` is unreliable — a pane that has exited pi back to a shell can
still report `pi`, and a shell can be mislabeled. Detect by **content signature**: a pi
agent pane renders a TUI status bar (model name + token-usage `NN%/262k`, an `MCP: x/y
servers` line, and/or a `Working...` / `Esc to interrupt` line). A shell shows a prompt
glyph (`$`, `❯`, `%`) and no pi status bar.

The bundled script (`watcher.sh`, alongside this SKILL.md) auto-classifies every sibling
pane and watches only the pi agents. Run a one-shot classification first to confirm:

```bash
bash <skill_dir>/watcher.sh --classify
```

Show the user the discovered agent panes and **repeat the plan back** before looping.

## Step 3 — Confirm cadence with the user

Defaults: poll every **300s** (5 min), confirm idle over **2** consecutive polls before
nudging. Let the user override (`--interval`, `--confirm`). Re-nudge fires every
`confirm` idle polls so a missed keystroke is retried.

## Step 4 — Run the watch loop

```bash
# Auto-discover agents, poll 5m, confirm idle x2, exclude self automatically
timeout 1500 bash <skill_dir>/watcher.sh --interval 300 --confirm 2
```

The harness times out long bash calls (~code 124) — that is expected. Re-invoke the same
command to keep watching. The nudge sent to a halted agent is:
`continue your work, if any is left`

## Step 5 — Handle "deliberately finished" agents

Before/after a nudge, capture the pane and read the agent's last message:

```bash
tmux capture-pane -t <pane_id> -p | grep -v '^$' | tail -25
```

If the agent says it has **no autonomous work left** and is waiting on a user decision
(approval to push, a choice between options, etc.), that is a *legitimate* stop — stop
nudging that pane and report the gated options to the user. Only keep nudging panes that
look mid-task or interrupted.

## Notes

- The script never sends keys to `$TMUX_PANE` (self).
- A pane that disappears (closed) is logged and skipped.
- To watch a fixed set instead of auto-discovery: `--panes "%3 %5"`.
- To exclude extra panes from auto-discovery: `--exclude "%2 %4"`.
