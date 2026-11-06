---
name: subagent
description: Delegate a bounded research or implementation task to a separate non-interactive pi process to conserve the main agent's context. Use when about to do a deep code dive or a self-contained implementation that can be handed off. Spawns a Sonnet subagent (read-only tools for research, full tools for implementation) with the task prompt and final result persisted as markdown under .pi/tmp/<task_id>/.
---

# Subagent Delegation

Offload a deep code investigation ("research") or a self-contained implementation to a
separate, non-interactive `pi` process. The subagent runs with its own context window, so
the main agent only pays for the small distilled report it reads back — not the entire
exploration/implementation trace.

Use this when you (the main agent) are about to either:
- **Research**: do a deep code dive / investigation, or
- **Implement**: carry out a bounded, well-specified change.

You author a precise task, spawn the subagent, wait for it to finish, then read its report.

---

## How it works

1. You write a complete `task.md` (template below) into `.pi/tmp/<task_id>/`.
2. You spawn a non-interactive `pi` subagent with `task.md` as its prompt.
3. The subagent runs to completion; its **final message** is captured verbatim as
   `result.md`. `result.md` contains **only the final output**, by design.
4. You check the exit code, then read `result.md` (the payoff).

The subagent:
- runs the **latest global Sonnet** model, **capped at a 128k context window**;
- has **MCP access** (via `mcp`) and all global skills;
- in **research** mode is **strictly read-only** (no shell, no edits);
- in **implementation** mode has the full toolset;
- is forbidden from spawning further subagents (recursion guard).

---

## task_id

A **stable, descriptive `snake_case` slug** derived from the task, e.g.
`investigate_bf16_import`, `refactor_auth_module`, `add_retry_to_syncer`.

- Reusing an existing `task_id` = **intentionally updating** that task (its `result.md`
  is overwritten on the next run). Always `ls .pi/tmp/` first and reuse vs. create
  accordingly.
- A genuinely new piece of work = a new, distinct slug.

---

## Step 1 — Write the task

Create `task.md` under `.pi/tmp/<task_id>/` **inside the main agent's current working
directory** (`mkdir -p .pi/tmp/<task_id>` first). All task artifacts live alongside the
project you are working in, never elsewhere. **Every section is mandatory.**

```markdown
# Task: <one-line objective>

## Mode
research | implementation

## Context
- Background / why this task exists.
- Known-relevant files & paths you (the main agent) already explored, with `file:line`
  refs where useful. Front-load everything you already paid to discover so the subagent
  does not re-derive it.
- Prior findings / decisions the subagent should treat as given.
- Constraints, conventions, gotchas.

## Instructions
1. Concrete, ordered, actionable steps the subagent must perform.

## Out of scope
- Explicitly what NOT to touch / do.

## Success criteria
- Objectively decidable checklist. NO vague/subjective items ("clean", "works well").
  - Implementation: each item is an assertion + how to verify it
    (e.g. `- [ ] Tests pass: \`make test\` exits 0`).
  - Research: each item is a question that must be answered WITH evidence
    (e.g. `- [ ] Root cause identified, with file:line evidence`).

## Deliverable
What result.md (your final message) must contain. It MUST restate each Success criterion
with its pass/fail status and the evidence proving it.
- Research: findings + `file:line` evidence + a recommended fix and at least one alternative with tradeoffs.
- Implementation: summary of changes, list of files modified, and how to verify (build/test command + result).
```

The criteria/instructions are authored fresh per task — the examples above only show the
required *shape* of a well-formed entry.

## Step 2 — Prepare the subagent config dir (idempotent)

The subagent runs with a dedicated config dir (`~/.pi/agent-sub`) so its 128k context cap
never touches your global settings. Shared resources are symlinked from `~/.pi/agent`;
only `settings.json` is regenerated each spawn so the cap is keyed to the model actually
chosen. Run this before every spawn:

```bash
SUB="$HOME/.pi/agent-sub"
G="$HOME/.pi/agent"
mkdir -p "$SUB"
for f in auth.json npm skills mcp.json mcp-cache.json models.json; do
  ln -sfn "$G/$f" "$SUB/$f"
done

# Dynamically pick the latest global Sonnet (auto-tracks future versions).
SUBAGENT_MODEL="$(pi --list-models 2>&1 | awk '{print $2}' \
  | grep -E '^global\.anthropic\.claude-sonnet-' | sort -V | tail -1)"

# Abort if model detection produced nothing (e.g. --list-models format changed):
# an empty model would otherwise flow into --model "" and a broken settings.json key.
if [ -z "$SUBAGENT_MODEL" ]; then
  echo "ERROR: could not detect a global Sonnet model from 'pi --list-models'" >&2
  echo "Inspect 'pi --list-models' output and adjust the grep/awk above." >&2
  return 1 2>/dev/null || exit 1
fi

# Regenerate settings: MCP only (no context-mode), 128k cap on the chosen model.
cat > "$SUB/settings.json" <<EOF
{
  "defaultProvider": "amazon-bedrock",
  "packages": ["npm:pi-mcp-adapter"],
  "providers": {
    "amazon-bedrock": {
      "modelOverrides": { "$SUBAGENT_MODEL": { "contextWindow": 128000 } }
    }
  }
}
EOF
```

## Step 3 — Spawn the subagent (blocks until done)

The subagent MUST run in the **same working directory as you, the main agent**, so its
relative paths, codebase reads, and (in implementation mode) edits all resolve against the
project you are working in. `pi -p` uses the spawning process's current directory, so the
spawn is wrapped in `(cd "$MAIN_PWD" && …)` to pin it explicitly. The task dir is anchored
under `$MAIN_PWD` for the same reason.

Set `TASK_ID` and choose the matching invocation. The recursion guard is applied in both
modes via `--append-system-prompt`.

```bash
MAIN_PWD="$(pwd)"            # the main agent's working directory
TASK_ID="<task_id>"
DIR="$MAIN_PWD/.pi/tmp/$TASK_ID"
TIMEOUT=900                  # hard wall-clock cap (seconds) so a wedged subagent
                            # cannot hang the main agent indefinitely. Tune per task.
GUARD="You are a delegated subagent executing a single bounded task. Do NOT spawn further \
subagents or invoke the subagent/delegation skill. Complete the task yourself and end with \
a concise final report; that report is your only output. Verify and report each Success \
criterion with pass/fail and evidence."
```

**Research mode** — strictly read-only (+ MCP):

```bash
( cd "$MAIN_PWD" && PI_CODING_AGENT_DIR="$SUB" timeout "$TIMEOUT" pi -p \
  --model "$SUBAGENT_MODEL" \
  --tools read,grep,find,ls,mcp \
  --append-system-prompt "$GUARD" \
  @"$DIR/task.md" > "$DIR/result.md" 2> "$DIR/error.log" )
EXIT=$?
```

**Implementation mode** — full toolset (+ MCP):

```bash
( cd "$MAIN_PWD" && PI_CODING_AGENT_DIR="$SUB" timeout "$TIMEOUT" pi -p \
  --model "$SUBAGENT_MODEL" \
  --append-system-prompt "$GUARD" \
  @"$DIR/task.md" > "$DIR/result.md" 2> "$DIR/error.log" )
EXIT=$?
```

## Step 3.5 — Live progress channel (optional): `bus`

The spawn in Step 3 **blocks** the main agent until the subagent exits, so by default you
only see the distilled `result.md` at the end — nothing while it runs. When you want
visibility into a long task, or when several subagents must coordinate, use the `bus` CLI
(a zero-dependency append-log pub/sub; run `bus --help`). It is persistent and replayable,
so progress survives the run and can be inspected afterward even if you never watched live.

**Wire the subagent to publish progress.** Add an instruction to `task.md` telling the
subagent to emit a line per milestone, and pass a shared topic + a distinct `AGENT_ID` in
its environment:

```markdown
## Instructions
...
N. After each major step, publish a one-line progress note:
   `bus pub "$PROGRESS_TOPIC" "<what you just finished>"`.
   On completion publish a final line beginning with `DONE:` (or `FAILED:` on error).
```

Spawn with the topic and a per-subagent id exported so its records are attributable:

```bash
PROGRESS_TOPIC="subagent/$TASK_ID"
( cd "$MAIN_PWD" && PI_CODING_AGENT_DIR="$SUB" \
    AGENT_ID="sub:$TASK_ID" PROGRESS_TOPIC="$PROGRESS_TOPIC" \
    timeout "$TIMEOUT" pi -p \
    --model "$SUBAGENT_MODEL" \
    --append-system-prompt "$GUARD" \
    @"$DIR/task.md" > "$DIR/result.md" 2> "$DIR/error.log" ) &
SPAWN_PID=$!
```

**Watch live** (the `&` above backgrounds the spawn so you can tail while it runs):

```bash
bus sub "$PROGRESS_TOPIC" &      # follow new progress lines as they arrive
SUB_PID=$!
wait "$SPAWN_PID"; EXIT=$?       # block on the subagent as before
kill "$SUB_PID" 2>/dev/null || true
```

Or skip the live tail and **replay the whole progress trail** after it finishes:
`bus cat "$PROGRESS_TOPIC"`.

**Coordinating multiple subagents.** Give each a distinct `AGENT_ID` and either a shared
topic (fan-in: one `bus sub` sees every worker's progress, filterable with
`--from sub:<task_id>`) or per-task topics. Because the log is append-only and
flock-serialized, concurrent publishers never corrupt each other.

This channel is **advisory only**: `result.md` + `EXIT` remain the source of truth for
success/failure (Step 4). Progress lines are for observability and coordination, not for
deciding whether the task passed.

## Step 4 — Read the result

```bash
echo "exit=$EXIT"
```

- **`EXIT` == 0 and `result.md` is non-empty** → read `$DIR/result.md` (i.e.
  `.pi/tmp/<task_id>/result.md` under the main pwd). That report is the payoff; consume it
  directly. Confirm each Success criterion is reported pass/fail with evidence.
- **`EXIT` == 0 but `result.md` is empty** → treat as a failure: the subagent exited
  cleanly without producing a final message. Inspect `$DIR/error.log`, refine `task.md`,
  and re-run the same `task_id`. Always gate the read on a non-empty check:
  `[ -s "$DIR/result.md" ] || echo "empty result — treat as failure"`.
- **`EXIT` == 124** → the subagent hit the `$TIMEOUT` wall-clock cap and was killed. The
  task is too large or the subagent wedged. Inspect `result.md` (partial) and
  `error.log`, then narrow the task scope or raise `TIMEOUT` before re-running.
- **`EXIT` != 0 (other)** → inspect the tail of `$DIR/error.log` plus whatever is in
  `result.md`, surface the failure, and decide whether to refine `task.md` and re-run the
  same `task_id`.

---

## Lifecycle

- `.pi/tmp/<task_id>/` **persists** — tasks can be referenced and updated later.
- Re-running the same `task_id` **overwrites** `result.md` / `error.log` in place.
- Nothing is auto-pruned. To discard a finished task manually: `rm -rf .pi/tmp/<task_id>`.

## Notes

- `result.md` captures only the subagent's final message (`pi -p`), not its step-by-step
  trace — intentional, to keep your read-back cheap.
- In implementation mode the subagent edits real files in the working tree; `result.md` is
  its summary of those changes, not the changes themselves.
- The subagent has all global skills available, but not `context-mode`.

## Authentication

The subagent authenticates the same way the spawning process does: the symlinked
`auth.json` plus the **AWS credential chain inherited from the spawning shell's
environment**. For the `amazon-bedrock` provider, export the credentials before spawning
so the subagent inherits them:

```bash
export AWS_PROFILE=personal_bedrock AWS_EC2_METADATA_DISABLED=true
```
