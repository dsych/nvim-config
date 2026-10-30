#!/usr/bin/env bash
# tmux-copy-hint.sh - Copy a tmux-thumbs hint to buffer + system clipboard
# Usage: tmux-copy-hint.sh <text>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

text="${1:-}"
[ -z "$text" ] && exit 0

printf '%s' "$text" | "$SCRIPT_DIR/tmux-copy-text.sh" || exit 1
tmux display-message -l "Copied: $text"
