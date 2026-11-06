#!/bin/bash
# agent-watcher: monitor sibling pi agent panes in the current tmux window and nudge
# any that have halted. Auto-distinguishes pi agent panes from plain shell prompts.
#
# Usage:
#   watcher.sh [--interval N] [--confirm N] [--panes "%3 %5"]
#              [--exclude "%2"] [--classify] [--nudge "text"]
#
#   --classify   Print pane classification (agent vs shell) and exit.
#   --panes      Watch exactly these pane ids (skips auto-discovery).
#   --exclude    Extra pane ids to skip during auto-discovery.
#   --interval   Seconds between polls (default 300).
#   --confirm    Consecutive idle polls before nudging (default 2).
#   --nudge      Prompt text to send (default "continue your work, if any is left").

set -u
INTERVAL=300
CONFIRM=2
NUDGE="continue your work, if any is left"
FORCE_PANES=""
EXCLUDE=""
CLASSIFY_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --interval) INTERVAL="$2"; shift 2;;
    --confirm)  CONFIRM="$2";  shift 2;;
    --panes)    FORCE_PANES="$2"; shift 2;;
    --exclude)  EXCLUDE="$2";  shift 2;;
    --nudge)    NUDGE="$2";    shift 2;;
    --classify) CLASSIFY_ONLY=1; shift;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

SELF="${TMUX_PANE:-}"

# Is a pane a pi agent? Detect by TUI status-bar signature in captured content.
# pi renders: a token-usage gauge "NN%/<num>k", an "MCP: x/y servers" line, and/or a
# "Working..." / "Esc to interrupt" activity line. A shell shows only a prompt glyph.
# IMPORTANT: only inspect the BOTTOM of the pane. capture-pane may return stale pi frames
# in scrollback for a pane that has since exited to a shell; a live pi TUI always pins
# its status bar to the last few rows, and a live shell shows its prompt there.
is_pi_agent() {
  local c; c=$(tmux capture-pane -t "$1" -p 2>/dev/null | grep -v '^[[:space:]]*$' | tail -6)
  [ -z "$c" ] && return 1
  if echo "$c" | grep -qE '(MCP: [0-9]+/[0-9]+ servers|[0-9]+%/[0-9]+k|Esc to interrupt|· (medium|low|high)$)'; then
    return 0
  fi
  return 1
}

# Is a pi agent pane actively working (spinner / elapsed / interrupt hint)?
is_working() {
  local c; c=$(tmux capture-pane -t "$1" -p 2>/dev/null)
  echo "$c" | grep -qE '(Working\.\.\.|Elapsed [0-9]|Esc to interrupt|[⠁⠂⠄⠈⠐⠠⠇⠋⠙⠹⠸⠼⠴⠦⠧⠏⡀⢀])'
}

discover() {
  local win panes p out=""
  win=$(tmux display-message -p '#{session_name}:#{window_index}')
  panes=$(tmux list-panes -t "$win" -F '#{pane_id}')
  for p in $panes; do
    [ "$p" = "$SELF" ] && continue
    case " $EXCLUDE " in *" $p "*) continue;; esac
    if is_pi_agent "$p"; then out="$out $p"; fi
  done
  echo "$out" | xargs
}

# Build watch list
if [ -n "$FORCE_PANES" ]; then
  WATCH="$FORCE_PANES"
else
  WATCH="$(discover)"
fi

if [ "$CLASSIFY_ONLY" -eq 1 ]; then
  win=$(tmux display-message -p '#{session_name}:#{window_index}')
  echo "window=$win self=$SELF"
  for p in $(tmux list-panes -t "$win" -F '#{pane_id}'); do
    tag="shell"
    [ "$p" = "$SELF" ] && tag="SELF(skip)"
    if [ "$p" != "$SELF" ] && is_pi_agent "$p"; then tag="pi-agent"; fi
    echo "  $p -> $tag"
  done
  echo "watching: ${WATCH:-<none>}"
  exit 0
fi

if [ -z "$WATCH" ]; then
  echo "No pi agent panes to watch (self=$SELF). Exiting." >&2
  exit 0
fi

echo "watcher start: panes=[$WATCH] interval=${INTERVAL}s confirm=$CONFIRM self=$SELF"
declare -A idle
for p in $WATCH; do idle[$p]=0; done

while true; do
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  for p in $WATCH; do
    [ "$p" = "$SELF" ] && continue
    c=$(tmux capture-pane -t "$p" -p 2>/dev/null)
    if [ -z "$c" ]; then
      echo "[$ts] $p: gone (pane closed?)"
      continue
    fi
    if is_working "$p"; then
      idle[$p]=0
      echo "[$ts] $p: WORKING"
    else
      idle[$p]=$(( ${idle[$p]} + 1 ))
      echo "[$ts] $p: idle (count=${idle[$p]})"
      if [ "${idle[$p]}" -ge "$CONFIRM" ]; then
        tmux send-keys -t "$p" "$NUDGE"
        sleep 1
        tmux send-keys -t "$p" Enter
        idle[$p]=0
        echo "[$ts] $p: >>> NUDGED"
      fi
    fi
  done
  sleep "$INTERVAL"
done
