# Kagi Assistant extension — design notes

These notes replace the earlier `AUDIT.md` and `PARSER_BUGS.md`, which were written for
pi 0.84 and contained several wrong assumptions. Facts marked **live** were observed
against `assistant.kagi.com` on 2026-11-05. Facts marked **sessions** come from 163 Kagi
replies recorded in earlier pi session files.

## Intent

Use the models in a Kagi Assistant subscription as pi's coding model. Kagi's models
cannot call pi's tools natively, so a managed Kagi profile teaches them to write tool
calls as plain text. The extension turns those calls into pi tool calls; pi executes
them and the results are relayed back as text.

Required behaviour:

- real tool use (pi's built-in and extension tools);
- honest cost: the server-reported `cost_usd` of every billed turn;
- a per-conversation spend cap that is enforced before a request is sent;
- conversation continuity across turns, reloads and restarts;
- pi thinking levels mapped to Kagi's `reasoning_effort`.

## pi 1.0.3 contract

- The stream receives a `TranscriptContext`. The system prompt and tools live in
  system messages (`getCurrentSystemPrompt`, `getCurrentTools`); later system messages
  add or remove tools mid-conversation.
- The stream honours `onPayload`, `onResponse` and `onProviderStreamEvent`, emits
  balanced block events, and ends with exactly one `done` or `error`.
- `options.reasoning` is a pi level; it is `undefined` when the level is `off`.
- pi validates and coerces tool arguments and returns failures to the model as error
  tool results, as for native providers.

## Kagi wire facts (live)

| Area | Fact |
|---|---|
| Auth | `Cookie: kagi_session=<token>`. A session link (`https://kagi.com/search?token=…`) carries the token in its `token` query parameter. |
| Catalog | `GET /api/init` → `models.models[]` with `reasoning_effort.options`, `access_level` (`standard`/`unlimited`) and `requires_search`; `has_unlimited_access` for the account. |
| Profiles | `GET /api/assistants` (array), `POST /api/assistants` (201), `PATCH /api/assistants/<uuid>`. A patch applies to existing conversations immediately. A deleted profile → `404 "Custom assistant not found"`. |
| Turns | `POST /api/v2/conversations` or `/api/v2/branches/<branch>/respond` → conversation, branch and turn uuids. The branch uuid stays the same across responses, including after a model switch. |
| Expiry | API conversations are temporary (`temporary_duration: "24h"`). A missing branch → `404 "Branch not found"`. |
| Stream | `GET /api/v2/turns/<turn>/stream` (SSE). Node kinds: `assistant_message`, `activity`/`config`, `activity`/`thinking`, `activity`/`tool_call`, `text`. A thinking node's first text is in `node.created.payload.content`; `node.completed.payload.content` holds a node's final text. Ends with `{"is_final": true, "billing": …}`. Re-attaching to a finished turn replays its frames. |
| Usage | `turn.completed.payload.usage`: `input_tokens` **includes** `cache_read_tokens` (7351 input with 7098 cached; the cost fell from $0.0022 to $0.00015). |
| Cancel | Closing the stream does not stop a turn: it completes and is billed, and responding before then → `409 request_state_changed`. `POST /api/v2/turns/<turn>/cancel` → 204, the stream ends with `turn.cancelled`, the turn reports no cost, and the plan's included usage did not change (1,000+ output tokens cancelled). |
| Built-in tools | Every model has Kagi tools (`file_info`, `find_files`, `librarian`, `list_directory`, `read_file`, `search`, `search_files`) over an empty server sandbox. No request field disables them (5 variants tried). A native call to any other name gets `Unknown tool name` back inside the turn. |
| Overhead | Kagi adds about 2,900 prompt tokens to every turn. |

## Tool calls

### Text calls (sessions)

Of 163 recorded replies, 71 were executed. At least 50 contained a call that was not:
prose before the block, a missing `</function_calls>`, `<function=read">`, `<offset>320`
instead of `<parameter=offset>`, parameters without a `<function=…>` element, two blocks
in a row, and Claude-style `<invoke name="…">`/`<parameter name="…">`. Models also quote
the syntax in fenced examples when asked about it.

The parser therefore:

- accepts both call syntaxes, prose around blocks, missing or mistyped closing tags,
  several blocks, stray quotes, and known parameters written as `<KEY>…</KEY>` or, as
  DeepSeek did live on 2026-11-10, `<KEY>…</parameter>`;
- ends a value only at a `</parameter>` followed by more markup, so a value may contain
  the protocol itself;
- infers the tool when parameters appear without a function element and exactly one
  declared tool matches them;
- ignores markup mentioned inside a line of prose, and runs a fenced block only when
  every call names a declared tool and nothing follows the fence;
- emits every recognised call and leaves argument validation to pi.

Markup is withheld from the live text, so the user sees prose and tool calls only.

### Native calls (live)

Claude called pi's `read` through its native function interface instead of writing
text; Kagi answered `Unknown tool name` and the model concluded it had no access. The
`tool_call` node carries the tool name and final arguments, so a native call to a
declared tool becomes a pi tool call. When the model moves to its next step, the
extension cancels the turn and discards the rest, which only reacts to the failure. The
next message tells the model that the harness ran the call anyway.

### Corrections

A reply that attempted a call but produced nothing runnable, or that used Kagi's sandbox
file tools, gets a correction message in the same conversation (up to 2 per pi call).
Text written after a sandbox file tool is held back meanwhile: it usually reports the
user's files as missing. Built-in tools are not interrupted, because GPT-6-luna explored
with them and then wrote a valid call in the same turn; cancelling them made it fail.

## Conversation delivery

pi sends the whole context on every call; a Kagi conversation is stateful. Per pi
session the extension stores how many transcript messages the Kagi conversation has
received and a hash of that prefix, plus hashes of the system prompt and tools last sent.

On each call:

1. If the stored prefix no longer matches the context (edit, rewind, compaction, tree
   navigation, fork), start a new Kagi conversation and send the system prompt, tools
   and full history.
2. Otherwise send everything after the prefix: user messages, tool results, and turns
   from other models. The conversation's own previous reply is recognised by its turn
   uuid and skipped. A changed system prompt or tool list is sent as an update.
3. With nothing new (a retry), ask the model to continue.

State is saved as soon as Kagi accepts a message, because the conversation contains it
whether or not the reply succeeds. An expired conversation falls back to step 1.

### Request-local messages (live)

Another extension's `context` hook can add a message to one request only. context-mode
appends a routing note to the first request of every run; pi passes it as a user message
without a timestamp, and the request after the tool call no longer contains it (checked
on pi 1.0.3 and 1.5.2). Counting the note in the prefix made every tool round trip look
like an edited history (step 1), so each one started a new Kagi conversation with the full
transcript: 126,000 characters with a 30-tool setup. The note also became the newest user
message, so the user's prompt was sent as replayed history.

A user message without a timestamp is therefore request-local. It is relayed where it
appears, after the prompt it follows, but it is not part of the stored prefix, and a
request whose only new message is request-local counts as a retry. An extension that
gives such a message a timestamp still causes a new conversation.

## Unfinished turns and the spend cap

Every reported cost counts toward the cap, including failed turns. An aborted turn is
cancelled on Kagi. A turn whose cost is unknown (stream cut, failure without usage) is
saved as unsettled; the next call waits for it (`GET /api/v2/turns/<turn>`, up to 2
minutes), adds its cost to the cap and to the next reply, then sends. A `409` while
sending triggers the same wait and one retry.

## Known limits

- Images are noted in text only (Kagi supports uploads; not implemented).
- The cap can be exceeded by one turn, because a turn's cost is known only afterwards.
- Cancelled turns report no cost; the evidence that they are free is one unchanged
  plan-usage reading.
- Kagi's ~2,900-token overhead applies to every turn.
