---
name: delegated-implementation-loop
description: Drive a larger, multi-task change to completion by delegating bounded TDD tasks to subagents while the main agent stays the driver+validator — owning the spec, the tracker, git, and independent validation. Use when turning a fully-formed design into an ordered task breakdown (planner), executing each task via a delegated implementer subagent, then running an adversarial critique pass with per-task local commits. Records the goals/contracts for each role (main orchestrator, planner subagent, implementer subagent, critiquer subagent, analysis subagent). Triggers on "break this design into tasks", task breakdown/planning, multi-task delivery, "orchestrate the implementation", driver/validator loop, delegated TDD execution, "run the task breakdown", per-task commit workflow.
---

# Delegated Implementation Loop

A repeatable way to deliver a larger change that has been broken into tasks: the **main
agent is the driver + validator**, and each task is executed by a **delegated subagent**.
The main agent never lets a subagent's self-report stand as truth — it independently
re-derives correctness, then commits. This conserves the main agent's context (each task's
exploration/edit trace stays in the subagent) while keeping a human-quality gate on every
change.

Built on the **`subagent`** skill (read it for the spawn plumbing: config dir, model
selection, `task.md` shape, spawn invocation, exit-code handling). This skill adds the
**orchestration loop** and the **role contracts** around those spawns.

---

## When to use

- The work is already decomposed (or decomposable) into ordered, individually-testable
  tasks with dependencies.
- Each task is bounded enough to specify precisely and verify objectively.
- You want per-task commits, an audit trail, and a final critique — not one giant diff.

If it is a single self-contained task, just use the `subagent` skill directly. This skill
is for the **loop over many tasks** plus the critique/analysis roles.

---

## Roles & goals

### 1. Main orchestrator (you) — driver + validator
**Goal: own the spec, the tracker, git, and the truth. Decompose, delegate one task at a
time, independently validate every result, then commit. Never trust a report you did not
re-verify.**

Responsibilities:
- **Own the tracker doc** (a breakdown + status table). Subagents are forbidden from
  editing it; you update each row only after you validate.
- **Capture a green baseline first** (`build` then full `test`) and record the exact
  pass/skip counts. Every task is judged against this moving baseline.
- **Author each `task.md` precisely**: exact `file:line` refs, near-pseudocode for the
  algorithm, explicit *Out of scope*, an objectively-decidable *Success criteria*
  checklist, and a *Deliverable* that restates each criterion with evidence. Front-load
  everything you already paid to discover so the subagent does not re-derive it.
- **Spawn one subagent per task** (see spawn pattern below). Wait, then **validate
  independently** — do NOT take the report at face value:
  - read the actual `git diff` of the changed files,
  - re-run the targeted tests AND the full gate (`build` then `test`) yourself,
  - check the success criteria, TDD discipline (tests written first / shown failing),
    and **scope isolation** (only the intended files changed; ignore the auto-regenerated
    version stamp),
  - re-spawn the same `task_id` with a refined `task.md` on any failure.
- **Commit per task, locally, only after validation passes** — follow the repo's commit
  guidance. **Never push** without explicit user approval.
- **Validate critique findings before acting** (see the F-false-positive lesson below).
  This applies equally to the **test-quality reviewer**: adopt its deletions/merges only
  after checking the named survivor exists and pins the same branch, and **override** it
  where a non-behavioural pin is a contract (a design-mandated comment, a persisted key,
  a file's existing literal-pin convention). Record every override.
- **Restructure the plan when reality demands it**: merge tasks when splitting them would
  produce half-broken intermediate commits; fold a task that turns out to need no source
  change into its integration test. Record the merge in the tracker.
- **Handle environment failures** (e.g. a corrupted test-runtime): a clean rebuild is your
  job, not the subagent's, and failures unrelated to the diff (e.g. missing fixture files
  in a freshly rebuilt env) must be diagnosed before blaming the change.

### 2. Planner subagent — design → ordered, TDD-isolated task breakdown
**Goal: given a fully-formed design, produce the task breakdown the rest of the loop
consumes — a sequence of isolated, individually-testable tasks that build on one another,
with an explicit integration-test task at every point where multiple tasks come together.**

Contract:
- **Read-only** (reads the design doc + explores the codebase; emits the breakdown as its
  `result.md` deliverable — it does NOT write source or the tracker).
- Ground every task in the design: cite the design section each task implements; do not
  invent scope the design did not call for, and do not drop scope it did.
- **Task-structuring rules (the user's guidance):**
  - **Isolated & TDD-testable** — each task is a single coherent change with an objectively
    decidable acceptance test; it can be specified precisely (`file:line` + near-pseudocode)
    and verified on its own.
  - **Build on one another** — order tasks by dependency so each starts from the previous
    task's completed, green state and **leaves the full suite green** (no task depends on a
    later task to compile/pass).
  - **Explicit integration tests at every seam** — whenever two or more tasks combine to
    produce a behavior, add a dedicated integration-test task (e.g. `IT-1`, `IT-2`) that
    exercises their interaction end-to-end, distinct from the unit tasks.
  - **Right-sized, not over-split** — do not split tightly-coupled changes that would force
    a half-broken intermediate commit; group them into one task (the orchestrator will also
    merge such tasks, but the plan should pre-empt it). Conversely, do not bundle unrelated
    changes.
  - **Bookend tasks** — include a final comment/doc **sanitization** task (self-contained
    comments, no cross-references) and a final **critique** task as the last items.
- Deliverable: an ordered breakdown table (id · description · design ref · dependencies ·
  test strategy / acceptance criterion · is-integration-test) plus a one-line statement of
  the green baseline each task is measured against. The orchestrator reviews this, adopts it
  as the tracker, and owns all subsequent edits to it.

### 3. Implementer subagent — one task, TDD, green gate, in scope
**Goal: implement exactly ONE task using TDD (failing tests first), iterate to a green
build+test gate with no regressions and no out-of-scope edits, and report each success
criterion with evidence.**

Contract (encode in `task.md` + the spawn GUARD):
- Implement only the one task. Write/adjust tests FIRST and show them failing pre-impl.
- Iterate with the targeted test command; **final gate = `build` then `test` (no args),
  both exit 0, no regressions vs the recorded baseline + the task's new tests.**
- **Forbidden:** editing the tracker or anything under `.pi/tmp/`; touching files outside
  the declared scope; committing/pushing; bumping version constants; `git stash`/`git
  checkout` (no discarding state); spawning further subagents.
- Comments/docstrings must be **self-contained** — explain only the annotated code; no
  references to task numbers, design-doc sections, prior conversation, or internal
  codenames/packages/URLs (matters for public-facing code).
- Deliverable: `result.md` restating each success criterion pass/fail with evidence (new
  test names, pre-impl failure output, final test summary line, `git diff --stat`).

### 4. Critiquer subagent — adversarial, read-only, grounded
**Goal: hunt for real, code-anchored defects in the finished change, grounded in the design
docs so accepted tradeoffs are NOT re-raised; deliver a severity-rated findings list and a
verdict with a must-fix set.**

Contract:
- **Read-only.** No edits, builds, tests, or commits.
- Read the design doc + the breakdown + any review tracker FIRST, so it knows the intended
  behavior and the **explicitly accepted non-goals/tradeoffs**.
- Each finding: title, severity (Critical/High/Medium/Low), `file:function:lines`,
  step-by-step failure scenario, fix direction.
- Anything adjacent to an accepted tradeoff must be labeled **"ACCEPTED TRADEOFF (not a
  defect)"** so it is not mistaken for an action item.
- End with a verdict (ship / ship-with-fixes / needs-rework) and a prioritized must-fix
  list, plus prioritized test-coverage gaps.
- **The orchestrator then validates each finding before acting** — a critique can be wrong.
  (In practice a "must-fix" was empirically disproven by running the suspect test 25×; a
  finding that rests on an assumption about reachable states must be checked against the
  actual code/defaults before it drives any change.)

### 5. Test-quality reviewer subagent — adversarial, read-only, test-focused
**Goal: audit the tests the change added or modified as their own artifact — find redundant
tests, over-mocked/invocation-checking tests that never observe behaviour, tautological
assertions, and tests with no behavioural anchor — and deliver a per-test table, a
defect list with a named survivor or replacement assertion for every action, a keep-list,
and a net-effect estimate.** Spawn it **alongside** the code critiquer (both read-only, both
can run concurrently since neither edits).

Contract:
- **Read-only.** No edits, builds, tests, or commits. Tell it to load the `code-review`
  skill and apply its **§10 Test quality** rules (the four defect categories, the rules of
  engagement, the keep-list, the survivor check).
- Give it up front: the commit range, the test files/sections touched, the production
  functions under test, and the **established mocking boundary and necessary fakes** of
  the codebase (so it does not flag conventions as defects), exactly as the critiquer is
  given the accepted tradeoffs.
- Deliverable: (1) a table of every added/changed test — what it asserts on (return value /
  state / filesystem / emitted values / mock call args / mock ordering / literal), what it
  mocks, which production branch it exercises; (2) the defect list grouped by category,
  each entry `file::test (line)` + reason + DELETE (naming the covering test) / MERGE (into
  which, carrying which assertions) / REWRITE (the behavioural assertion to use);
  (3) a ≤ 8-item keep-list of the tests pinning the safety-critical behaviour; (4) net
  effect + a per-branch survivor table for every deletion/merge; (5) any **side finding**
  about production code a no-anchor test exposed (an unobservable branch is often dead
  code).
- **The orchestrator validates before applying**: grep that every named survivor exists,
  confirm the keep-list is untouched except for merged-in assertions, and apply overrides
  for contract pins. Then run the cleanup as one implementer task (with the overrides
  written into its `task.md`) through the normal validate-and-commit step.

### 6. Analysis subagent (optional) — read-only, quantitative, honest
**Goal: turn raw results (benchmarks, logs, data) into a like-for-like comparison and a
clear recommendation, honest about statistical weakness, grounded in the design intent and
accepted non-goals. Be sure to instruct this agent to use the review skill. Use both the main model
and latest numbered gpt model (non oss).**

Contract: read-only; compare only comparable arms (exclude mismatched ones and say why);
report absolute + % deltas with direction; separate signal from noise (call out single-run
/ small-sample weakness); tie any anomaly to a specific code path or critique finding;
recommend a design change ONLY with evidence, never re-litigating accepted non-goals.

---

## The loop

```
P. Plan (once, up front): given the fully-formed design, spawn the read-only planner to
   produce the ordered, TDD-isolated breakdown (integration-test tasks at every seam).
   Review and adopt it as the tracker. (Skip if a breakdown already exists.)
0. Baseline:  build → test (no args) → record pass/skip counts on a clean tree.
1. For each task in dependency order:
     a. Write .pi/tmp/<task_id>/task.md (precise: file:line, pseudocode, out-of-scope,
        success-criteria checklist, deliverable). Reuse merged scope if you consolidated.
     b. Spawn ONE implementer subagent (always Opus — see spawn pattern). Wait.
     c. VALIDATE independently:
          - git diff the changed files (read the real change, not the report)
          - re-run targeted tests + full gate (build → test); confirm baseline + new tests
          - check success criteria, TDD (tests-first/failing), scope isolation
        On fail → refine task.md, re-spawn same task_id. (Restructure/merge if needed.)
     d. Commit locally (repo commit guidance). Do NOT push. Update the tracker row
        (commit hash + delta vs baseline).
2. Review pass — spawn TWO read-only reviewers, concurrently:
     a. the code critiquer (role 4) with the accepted-tradeoff list;
     b. the test-quality reviewer (role 5) with the mocking-boundary/necessary-fakes list.
   VALIDATE both (false-positive guard; survivor grep for every proposed test deletion).
   Triage: blockers → new task(s) back through step 1; test cleanup → one implementer task
   carrying your overrides; non-blockers → record as follow-ups (optionally implement the
   should-fix ones the same way). A no-anchor test that exposes dead production code is a
   production finding — route it through step 1, not the test cleanup.
3. If results need measuring (benchmark/data): spawn the analysis subagent; act on its
   recommendation per the gating it states.
4. Mark the implementation DONE in the tracker. Surface the follow-up list. Do not push
   or take design-reversing/benchmark-gated actions without user direction.
```

---

## Spawn pattern (orchestration-specific)

Follow the `subagent` skill's Step-2 config-dir setup. Two deltas for this loop:

1. **Model:** **always use the latest global Opus for every subagent in this loop**
   (planner, implementer, critiquer, analysis — no exceptions, regardless of task
   difficulty). Override the `subagent` skill's auto-selected Sonnet with the latest
   global Opus and key the 128k cap to it in `settings.json`:
   ```bash
   SUBAGENT_MODEL="$(pi --list-models 2>&1 | awk '{print $2}' \
     | grep -E '^global\.anthropic\.claude-opus-' | sort -V | tail -1)"
   ```
2. **GUARD:** extend the recursion guard with the isolation rules so a subagent cannot
   corrupt the orchestration state:
   ```bash
   GUARD="You are a delegated subagent executing a single bounded task. Do NOT spawn \
   further subagents or invoke the subagent/delegation skill. Do NOT edit any file under \
   .pi/tmp/ (no tracker edits). Do NOT git commit or push. Do NOT use git stash or git \
   checkout. Complete the task yourself and end with a concise final report; that report \
   is your only output. Verify and report each Success criterion with pass/fail and \
   evidence."
   ```
   For a **planner / critiquer / test-quality reviewer / analysis** subagent, add:
   "Read-only: do NOT modify, build, test, run, or commit anything," and spawn with the
   research toolset (`--tools read,grep,find,ls,mcp`; add `bash` only when the reviewer
   must run `git diff`/`git log` over a commit range, and keep the read-only guard).

Spawn, capture `result.md`/`error.log`, and handle exit codes exactly as the `subagent`
skill describes (EXIT 0 + non-empty → read; EXIT 0 + empty → failure; 124 → timeout; other
→ inspect `error.log`). Use a generous `TIMEOUT` for tasks that run multiple build+test
cycles.

---

## Hard-won principles (the user's guidance, distilled)

- **The main agent owns git, build, and validation.** Subagents generate diffs and
  reports; they never commit, push, stash, checkout, or bump versions.
- **One subagent per task.** Bounded scope keeps the spec precise and the validation cheap.
- **TDD is the contract, not a suggestion** — failing tests first; the only acceptance gate
  is `build` then `test` (no args) green with no regressions.
- **Never trust a self-report.** Read the diff, re-run the gate yourself, check scope and
  TDD. This applies to critique findings too — verify before you act (a confident
  "must-fix" can be a false positive once you check the code's actual defaults/states).
- **Commit per task, locally; never push without asking.**
- **Isolation:** only the intended files change; the auto-regenerated version stamp is
  ignored, never staged. A subagent touching out-of-scope files is a validation failure.
- **Self-contained comments** for public-facing code: no task/section/cross-component refs,
  no internal codenames/packages/URLs.
- **Restructure when reality demands it:** merge tasks whose split would yield half-broken
  intermediate commits; fold a no-source-change task into its integration test. Record it.
- **Diagnose env failures before blaming the diff** (a clean rebuild is the orchestrator's
  job; failures unrelated to the change must be isolated, not papered over).
- **Respect accepted non-goals end-to-end** — the critiquer and analysis subagents must be
  told them up front so they flag, not re-litigate, deliberate tradeoffs.
- **Review the tests too, as their own artifact.** The code critiquer hunts defects in
  production code; the test-quality reviewer hunts redundancy, over-mocking, tautology and
  vacuous passes in the tests. Run both. A test that cannot fail is worse than no test —
  it hides the gap — and a test with no behavioural anchor is frequently pointing at dead
  production code (in practice: an age rule of `max(btime, ctime)` was always `ctime`, so
  the birth-time path was unobservable; the reviewer found it because no test could
  anchor on it).

---

## Tracker

Keep a single breakdown+status doc (under `.pi/tmp/<breakdown_id>/` or the repo's working
notes). Minimum columns: task id · description · status (☐/✅/folded) · commit hash · test
delta vs baseline. Append an **Implementation status** section at the end recording the
final gate result, the commit list, the critique verdict (with any validated false
positives), the test-quality review outcome (defects found, cases removed, orchestrator
overrides), and the open follow-ups. The **planner** authors the initial breakdown (as its
`result.md`); the orchestrator adopts it and is the **sole editor** thereafter — no other
subagent ever writes this doc.
```
