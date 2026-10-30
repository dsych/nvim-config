#!/usr/bin/env bash
# Snippet picker: fuzzy search JSON snippets, paste into caller pane
set -euo pipefail
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CALLER_PANE="${1:-}"
export TMUX_ACTION_TARGET="$CALLER_PANE"
SNIPPETS_FILE="$HOME/.config/tmux/snippets.json"

if [[ ! -f "$SNIPPETS_FILE" ]]; then
    echo "No snippets file: $SNIPPETS_FILE" >&2
    exit 1
fi

# Extract snippet names from JSON keys
names=$(jq -r "keys[]" "$SNIPPETS_FILE")

# fzf with preview showing the snippet content
selected=$(echo "$names" | fzf \
    --prompt="snippet> " \
    --preview="jq -r '.[\"'{}'\"]' \"$SNIPPETS_FILE\"" \
    --preview-window=right:60%:wrap \
    --reverse \
    --no-info)

[[ -z "$selected" ]] && exit 0

# Get snippet content
content=$(jq -r --arg k "$selected" '.[$k]' "$SNIPPETS_FILE")

# Load into tmux buffer and paste into caller pane
printf '%s' "$content" | "$SCRIPT_DIR/tmux-copy-text.sh"
tmux paste-buffer -p -t "$CALLER_PANE"
