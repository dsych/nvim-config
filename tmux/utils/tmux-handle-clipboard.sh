#!/usr/bin/env bash
# tmux-handle-clipboard.sh - Handles pane-set-clipboard hook
# Detects OPEN: prefix in clipboard buffer and opens the URL locally

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

content=$(tmux show-buffer 2>/dev/null)

case "$content" in
    OPEN:*)
        url="${content#OPEN:}"
        tmux set-buffer -- "$url"
        open "$url" >/dev/null 2>&1
        ;;
esac

exit 0
