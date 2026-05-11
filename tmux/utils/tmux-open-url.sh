#!/usr/bin/env bash
# tmux-open-url.sh - Opens a URL in the browser
# On macOS (local): uses 'open' directly
# On remote (SSH): writes to ~/ssh_shared/.open_url for local watcher to pick up

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

url="$1"
[ -z "$url" ] && exit 0

if [ "$(uname -s)" = "Darwin" ]; then
    open "$url" >/dev/null 2>&1 &
else
    echo "$url" > "$HOME/ssh_shared/.open_url"
    tmux display-message "Opening on local: $url"
fi
