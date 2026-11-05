# Kagi Assistant for pi

Use the models in a Kagi Assistant subscription as pi's model (`/model kagi/<id>`), with
pi's tools, Kagi's server-reported cost, a per-conversation spend cap, and conversations
that survive pi restarts.

Kagi's models cannot call pi's tools natively. A managed Kagi profile teaches them to
write calls as plain text; the extension turns that text into pi tool calls and sends the
results back. It also accepts a call made through the model's native function interface
when it names a pi tool. Design details and the observed Kagi wire format are in
[DESIGN.md](DESIGN.md).

## Setup

1. Put a Kagi session token in `~/.kagi_session_token`. Either the cookie value or a
   Kagi *session link* (`https://kagi.com/search?token=…`) works.
2. Link the extension with the repository's `install.sh`, or run `/reload` if it is
   already linked.
3. Select a model: `/model kagi/deepseek-v4-1-flash`.

Token lookup order: `$KAGI_SESSION_TOKEN`, the token saved by `/kagi-login`
(`~/.pi/kagi.json`), then `~/.kagi_session_token`.

## Commands

| Command | Effect |
|---|---|
| `/kagi-login` | Validate a token or session link, save it, reload the catalog. |
| `/kagi-budget [usd]` | Show spending in this conversation and on the Kagi plan, or set the cap (default $3). |
| `/kagi-new-thread` | Start a new Kagi conversation on the next message; the full transcript is resent. |

## Behaviour

- **Models.** The catalog comes from your account. Models your plan cannot use are hidden.
- **Thinking levels.** pi levels map to the model's `reasoning_effort` options. `off`
  maps to `none` where the model has it. Levels a model lacks are hidden and pi uses the
  nearest one. A reasoning model always gets an explicit effort.
- **Cost.** Each reply's cost is Kagi's `cost_usd` for the turn. Token rates are zero
  because Kagi publishes none.
- **Spend cap.** Checked before each request; a blocked request sends nothing. One turn
  can exceed the cap, because its cost is known only afterwards.
- **Continuity.** One pi session uses one Kagi conversation, resumed after restarts. An
  edit, rewind, compaction or tree navigation starts a new Kagi conversation that
  receives the whole transcript. Kagi deletes API conversations after 24 hours; the next
  message then starts a new one the same way.
- **Aborts.** Pressing Esc cancels the turn on Kagi as well. Kagi reports no cost for
  cancelled turns.

## Measured results

Live runs on 2026-11-05 (edit a file with the edit tool, then run it with bash):

| Model | Completed | Turns | Cost |
|---|---|---|---|
| deepseek-v4-1-flash | yes | 5 (1 correction) | $0.0050 |
| claude-5-5-haiku | yes | 3 | $0.0006 |
| gpt-6-luna | yes | 8 (3 corrections) | $0.0066 |
| minimax-m3-1-flash | yes (list + read task) | 2 | $0.0019 |

A correction is one extra message asking the model to use the declared tools; it happens
when a reply attempts a call that cannot run, or uses Kagi's own sandbox file tools.

## Known limitations

- Images are replaced by a note; the extension sends text only.
- Kagi adds about 2,900 prompt tokens to every turn.
- Kagi's built-in tools (`read_file`, `list_directory`, …) cannot be disabled. Some
  models try them first; they see Kagi's empty sandbox, not your files.
- A model switch inside a session keeps the Kagi conversation. This was verified for
  DeepSeek → Claude only.

## Development

```sh
node --test pi/tests/kagi-assistant.test.mjs
PI_PACKAGE_ROOT=/path/to/@earendil-works/pi-coding-agent \
  node --test pi/tests/kagi-assistant-stream.test.mjs
```

The first suite covers parsing, delivery and storage without pi. The second drives the
provider through pi's stream types against a scripted Kagi server. Neither uses the
network. `KAGI_DEBUG=1` logs request metadata to
`~/.pi/agent/kagi-assistant-debug.jsonl` (mode 0600).
