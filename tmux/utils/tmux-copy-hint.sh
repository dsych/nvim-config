#!/usr/bin/env bash
# tmux-copy-hint.sh - Copy a tmux-thumbs hint to buffer + system clipboard
# Usage: tmux-copy-hint.sh <text>

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

text="$1"
[ -z "$text" ] && exit 0

tmux set-buffer -w -- "$text"
tmux display-message "Copied: $text"
