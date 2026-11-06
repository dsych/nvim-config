---
name: code-review
description: Apply a rigorous, production-minded code review lens whenever reviewing
  code, a diff, a pull request, a CR (Code Review), or proposed changes — or when asked
  to critique, give feedback on, or assess the quality of code. Prioritizes correctness
  and resilience (error handling, retries on transient failures, failure modes),
  operability (alarms and monitoring on failure paths), testability (dependency
  injection, local validation over prod verification), encoding intent in the type
  system rather than documentation, structural design (encapsulation, separation of
  concerns), scalability (avoiding rate limits and unnecessary round-trips), and
  deployment/environment correctness, and test quality (redundant tests, over-mocked
  or invocation-checking tests that never observe behaviour, tautological assertions).
  Triggers on "review this code/CR/PR/diff", "what do you think of this change", "give
  feedback", "is this production-ready", "review the tests", "are these tests
  redundant/superficial", "test quality review".
---

# Code Review

Review code the way a senior engineer protecting a production service does: focus on
what breaks at 3am, what's impossible to test, and what the next person can't safely
change. Do not nitpick formatting — linters do that. Surface substantive risks and
concrete, actionable improvements.

## How to review

1. Read the actual diff/files. Understand the change's purpose before judging it.
2. Walk every checklist category below against the change.
2a. Several checklist items are **trigger rules** ("when you see X, require Y") — when
    the trigger condition is present in the diff, you must raise the finding; do not
    downgrade it to a passing note because the current scale looks small.
3. For each finding: state the problem, why it matters (the production or maintenance
   consequence), and a concrete fix. Cite the specific file and line.
4. Separate **blocking** issues (correctness, resilience, missing failure handling,
   untestable code) from **non-blocking nits** (naming, minor structure). Label each.
5. After judging the pieces in isolation, **step back and review the system as a
   whole** (category 9). The checklist finds local defects; the worst bugs live in the
   seams between correct pieces.
6. **Review the tests as their own artifact** (category 10). A test suite that is
   large but redundant, or that only checks mocks were called, gives false confidence
   and taxes every future change. Judge each test by what would make it fail.
7. If something is unclear, ask — don't assume the author's intent.

## Review checklist (in priority order)

### 1. Correctness & resilience — the highest bar
- Is there error handling on every I/O boundary (network, disk, API, secrets, external
  process)? Flag any unguarded external call.
- Are transient failures handled? External calls should tolerate retryable errors
  (throttling, timeouts, connection resets) with bounded retries and backoff.
- What happens on partial failure? Does one failed item silently abort or corrupt the
  rest of the work?
- Are timeouts and resource limits set on every external interaction?

### 2. Operability & observability
- For every failure path — especially scheduled jobs, background workers, and anything
  that runs unattended — **what happens if it fails, and how does the team find out?**
  Silent failure is a defect; require alarms/monitoring on failure paths.
- Are meaningful logs/metrics emitted at the points an operator would need them
  (start, key counts, branch decisions, errors)?

### 3. Testability
- Are dependencies (clients, sessions, config, time, randomness) **injected** rather
  than constructed inline? Inline construction makes failure paths impossible to test
  in isolation — flag it and suggest a seam.
- Can the important behavior — especially error handling — actually be exercised by a
  test? If not, the design lacks the seams to do so.
- **Require a stated local/offline validation path for any externally-deployed
  change.** Verifying in production is not a validation plan. If a local or offline
  path exists (SAM/local Lambda runtime, simulator, mocked integration,
  dependency-injected fakes), require it and reject prod as the first place unproven
  code runs. If no validation path is stated, ask for one; if the author claims none
  exists, make them confirm that before relying on production.
- Do tests cover failure and edge cases, not just the happy path?

### 4. Encode intent in the code, not in prose
- Push as much meaning as possible into the **type system**. Don't lean on generic
  types, comments, or documentation to convey what a value means or what states are
  legal — make the types themselves express and enforce it.
- Constrain values to their legal set at the type level rather than accepting loose,
  unconstrained primitives.
- When you see a fixed, known set of string/int constants used as values (statuses,
  kinds, labels, modes), **require an enum** (or equivalent closed type), not loose
  module-level constants or string literals. Loose constants don't constrain inputs,
  don't give exhaustiveness checking, and let typos through.
- Any value with more than one field (a pair, triple, or ad-hoc dict) returned or
  passed across a function boundary **must be a named type** (dataclass / NamedTuple /
  TypedDict / class), never a bare `tuple`/`dict`. A caller must understand it from the
  signature alone, without reading the implementation.
- No placeholders, unfinished markers, commented-out code, or dead/unexplained code in
  a change under review. If it's not ready, the diff isn't ready.

### 5. Structure & abstraction
- When code talks to an external service (HTTP API, SDK, datastore) in more than one
  place, or threads the same connection details (auth, base URL, endpoint, region)
  through multiple functions, **require a client class** that takes that config once at
  construction and exposes intent-named methods. Flag raw per-call-site request/SDK
  usage as the thing to replace.
- When one service goes through a factory/abstraction and a sibling service is built
  inline, **flag the inconsistency** — all external clients should follow the same
  construction pattern.
- Construction of clients/resources belongs in a shared factory or module, not
  duplicated.
- Each unit should have a single clear responsibility. Flag mixed concerns and leaky
  abstractions.

### 6. Code quality & style
- **DRY**: flag duplicated logic, copy-pasted blocks, and parallel code paths that
  should share an implementation. Repetition is a maintenance liability — the copies
  drift. Suggest extracting the shared part.
- Are the **important parts of the code properly encapsulated** behind abstractions
  that hide their internals and expose a clean, intentional interface? Core logic
  should not leak implementation details to its callers.
- Are abstractions at the **right level** — neither premature/over-engineered nor
  missing where complexity clearly warrants one?
- Are names precise and honest (functions, variables, types) so the code reads as its
  intent? Flag misleading or vague names.
- Is the change **consistent with the surrounding codebase** — established patterns,
  conventions, and idioms — rather than introducing a one-off style?
- Is control flow readable: early returns over deep nesting, manageable function size,
  cohesive units? Flag functions doing too much.

### 7. Scalability & efficiency
- When you see N independent calls to the same API in a loop (one per item/label/key),
  **ask whether one request can return all N results** (a single query, batch endpoint,
  or aggregation), and require it if so. Justify the cost against **future** load, not
  just today's: "it's only 8 calls now" is not a defense if the design multiplies as
  metrics/items are added.
- Check whether the API offers a server-side count/aggregate instead of client-side
  pagination that scans every record; unbounded scans grow until they time out.
- Avoid unnecessary round-trips, N+1 patterns, and unbounded loops over remote data.

### 8. Deployment & environment correctness
- Are external dependencies/endpoints actually **available in the target environment**
  (partition, region, account, network)? Flag unchecked assumptions about reachability.
- Are permissions scoped to the minimum needed (specific resources, not wildcards)?
- Are secrets sourced from a secret store, never hardcoded or logged?

### 9. Whole-system / integration review — step back from the lines
After checking each piece in isolation, stop reading the change as individual lines and
review it as one system. Hyper-focusing on a single implementation detail (one library
call, one function) misses the defects that only appear when the pieces are assembled.
- **Walk the change as a user/caller of the assembled system would.** Trace a real
  end-to-end path through it: who calls this, what do they pass, what do they get back,
  and does every producer's output actually reach and satisfy its consumer? Producer and
  consumer can each be individually correct yet disagree at the seam.
- **Hunt for integration bugs and regressions.** When a value, resource, or piece of
  state is produced in one place and consumed in another (a new host added here — is the
  config the connector reads updated there?; a field written here — is it read with the
  same meaning there?), confirm the two sides are actually wired together and stay
  consistent over time. Flag any gap where the pieces won't compose at runtime.
- **Apply architectural judgment, not just line judgment.** Does the overall design hang
  together? Do the new boundaries make sense, does control/data flow cleanly across
  them, and does the change preserve existing behavior and contracts for current callers
  (no silent regression)? Ask whether the system, as assembled, does what a user expects.

### 10. Test quality — judge each test by what would make it fail
Tests are code that must earn its keep. Review the added/changed tests as a set, not
one at a time, and classify each by **what it asserts on** (return value / resulting
state or filesystem / emitted data values / a mock's call args / mock call ordering /
a literal) and **which production branch it exercises**. Then hunt for these four
defects — flag only when you can name the covering test or the behavioural assertion
that should replace it; otherwise say "keep":

- **Redundant.** Two or more tests whose assertions would pass/fail together for every
  plausible bug: same code path, same predicates, only cosmetic input differences;
  parametrize cases that add no new branch (e.g. a `[none]` case whose false branch an
  exact-output test already pins); a unit test fully subsumed by an integration test in
  the same file that asserts a superset on the same inputs. Action: DELETE naming the
  survivor, or MERGE its unique assertions into the survivor.
- **Superficial / over-mocked.** The function under test is reduced to calling mocks and
  the test asserts `assert_called_once_with(...)` or call ordering, when a behavioural
  assertion on the **return value** or the **resulting state** (state file, filesystem,
  emitted datum values) was available. Worst form: mocking the very collaborator whose
  interaction *is* the behaviour (mocking `prune()` in a test meant to prove pruning
  happened). Action: REWRITE with a **stateful fake** — e.g. a fake whose side effect
  changes the next reading so the verdict observably flips — and keep at most one
  argument check where the argument is itself a contract (a budget, a threshold).
- **Tautological.** Asserts a mock returned what it was told to return; `CONSTANT ==
  literal` with no derivation or ordering relation; `inspect.getsource`/`signature`
  string checks; `TOKEN == "TOKEN"` lines; a helper re-implemented inline and compared
  to itself. These cannot catch a behavioural regression. Action: DELETE, or REWRITE
  to pin the behaviour (e.g. instead of `MIN_AGE == 3600`, assert the file at
  `now − 3600` survives and at `now − 3601` is deleted).
- **Missing behavioural anchor.** The test would still pass if the production function
  were replaced by a stub returning a fixed value — `result is None or <check>` is the
  classic vacuous pass. Action: REWRITE so the vacuous path becomes `pytest.skip(...)`
  or an explicit failure. **A test with no anchor is often a signal of dead production
  code** (the branch it meant to cover is unreachable) — say so when you see it.

Rules of engagement:
- **Respect the established mocking boundary.** External effects the codebase always
  mocks (network, cloud APIs, IMDS, SSH, `systemctl`, subprocesses) and *necessary*
  fakes (birth time on Linux, `time.monotonic` for budget tests, clocks) are not
  over-mocking. Judge whether a wiring test adds information the behavioural/integration
  tests do not, not whether wiring tests exist at all.
- **Some non-behavioural pins are contracts and stay.** A comment the design mandates, a
  persisted key (state-file field, metric name, hold value), a path shared with another
  package, or literal constant pins where that is the file's existing "no drift"
  convention. The test is a pin on a contract, not a test of behaviour — label it as
  such and keep it. Trim it to the contract (e.g. keep the persisted key, drop the
  in-memory enum values that are never serialised).
- **Produce a keep-list.** Name the ≤ 8 tests that most tightly pin the safety-critical
  behaviour so nobody touches them while pruning.
- **Prove nothing is lost.** For every DELETE/MERGE give the surviving test per
  production branch, and estimate the net effect (functions deleted/merged, parametrize
  cases dropped, approximate collected-case delta).

## Output format

Group findings by category, blocking first. For each:

- **[Blocking|Nit] file:line** — problem → why it matters → suggested fix.

After the per-category findings, add an **Off-checklist** section: any issue that does
not map cleanly to a category above but would bite in production, surprise a
maintainer, or break when a dependency/API/version changes. Do not force these into a
category and do not omit them — the checklist is a floor, not a ceiling. If there are
none, say so.

End with a one-line overall assessment: is the change safe to ship, and what are the
must-fixes before approval.
