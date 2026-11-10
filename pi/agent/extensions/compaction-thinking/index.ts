import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * compaction-thinking
 *
 * A compaction summary doesn't need the thinking budget the conversation runs at. For the
 * compaction only (manual /compact, the context threshold, and overflow recovery), this sets a
 * lower thinking level, then puts the previous level back whatever the outcome: a summary, a
 * failure, an abort, or another extension cancelling the compaction.
 *
 *   Claude Opus or Fable at "max"            -> "high"
 *   any llama.cpp model with thinking on     -> "off"
 *
 * llama.cpp means pi's built-in provider ("llama.cpp") and the older pi-llama extension's
 * ("llama-cpp"). Their thinking is a template switch (enable_thinking), so "off" disables it.
 *
 * How: pi's built-in compaction reads the session's thinking level when it builds the summary
 * request, after the session_before_compact handlers have run. So the level is lowered there and
 * restored on session_compact (success) or session_compact_failed (failure, abort, cancel). Both
 * come before pi's next ordinary request, including the retried turn after overflow recovery.
 * If neither arrives, the next run (agent_start) or quitting restores it.
 *
 * A level you choose yourself while the compaction runs is kept: the previous level is only put
 * back if the level is still the one set here. Each change is recorded in the session like any
 * thinking-level change, ending on the restored level, so resuming the session restores that.
 */

type ModelInfo = { provider?: string; id?: string; name?: string };

/** Matches Claude Opus and Fable model ids and names, from any provider: anthropic's
 *  claude-opus-4-8, Bedrock's us.anthropic.claude-fable-5-1, "Claude Opus 5.5", ... */
const CLAUDE_OPUS_OR_FABLE = /\bclaude[-\s](opus|fable)\b/i;
/** pi's built-in llama.cpp provider, and huggingface/pi-llama's */
const LLAMA_CPP_PROVIDERS = new Set(["llama.cpp", "llama-cpp"]);

export function isClaudeOpusOrFable(model: ModelInfo | undefined): boolean {
  return !!model && (CLAUDE_OPUS_OR_FABLE.test(model.id ?? "") || CLAUDE_OPUS_OR_FABLE.test(model.name ?? ""));
}

export function isLlamaCpp(model: ModelInfo | undefined): boolean {
  return !!model && LLAMA_CPP_PROVIDERS.has(model.provider ?? "");
}

/** The thinking level to compact at, or undefined to compact at the current one. */
export function compactionLevel(model: ModelInfo | undefined, level: string): string | undefined {
  if (isLlamaCpp(model)) return level === "off" ? undefined : "off";
  if (level === "max" && isClaudeOpusOrFable(model)) return "high";
  return undefined;
}

export default function (pi: ExtensionAPI) {
  // Set while the level is lowered: what to put back, and the level this extension set
  let lowered: { previous: string; applied: string } | undefined;

  const restore = () => {
    if (!lowered) return;
    const { previous, applied } = lowered;
    lowered = undefined;
    if (pi.getThinkingLevel() === applied) pi.setThinkingLevel(previous as any);
  };

  pi.on("session_before_compact", (_event, ctx) => {
    if (lowered) return;   // already lowered for this compaction
    const previous = pi.getThinkingLevel();
    const target = compactionLevel(ctx.model, previous);
    if (!target) return;
    pi.setThinkingLevel(target as any);
    // The level pi actually set (setThinkingLevel clamps to what the model supports)
    const applied = pi.getThinkingLevel();
    if (applied !== previous) lowered = { previous, applied };
  });

  pi.on("session_compact", restore);
  pi.on("session_compact_failed", restore);
  // Safety nets, should a compaction ever end without either event
  pi.on("agent_start", restore);
  pi.on("session_shutdown", restore);
}
