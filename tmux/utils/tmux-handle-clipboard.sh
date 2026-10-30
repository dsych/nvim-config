#!/usr/bin/env bash
# tmux-handle-clipboard.sh - Handles pane-set-clipboard hook
# Detects OPEN: prefix in clipboard buffer and opens the URL locally

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

content=$(tmux show-buffer 2>/dev/null)

case "$content" in
    OPEN:*)
        url="${content#OPEN:}"
        tmux set-buffer -- "$url"
        "$SCRIPT_DIR/tmux-open-url.sh" --local "$url"
        ;;
esac

exit 0
