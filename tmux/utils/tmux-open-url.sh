#!/usr/bin/env bash
# tmux-open-url.sh - Opens a URL in the browser
# macOS: uses 'open'
# Linux with desktop (GNOME, etc.): uses 'xdg-open'
# Remote headless: writes to ~/ssh_shared/.open_url for local watcher

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

url="$1"
[ -z "$url" ] && exit 0

if [ "$(uname -s)" = "Darwin" ]; then
    open "$url" >/dev/null 2>&1 &
elif [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
    xdg-open "$url" >/dev/null 2>&1 &
else
    echo "$url" > "$HOME/ssh_shared/.open_url"
    tmux display-message "Opening on local: $url"
fi
