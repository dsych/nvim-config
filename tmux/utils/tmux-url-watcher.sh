#!/usr/bin/env bash
# tmux-url-watcher.sh - Background daemon that watches ~/ssh_shared/.open_url
# and opens URLs in the local browser. Only one instance runs at a time.
# Launched by tmux.conf on local macOS sessions.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

PIDFILE="/tmp/tmux-url-watcher.pid"
URL_FILE="$HOME/ssh_shared/.open_url"
POLL_INTERVAL=2

# Exit if already running
if [ -f "$PIDFILE" ]; then
    existing_pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
        exit 0
    fi
    # Stale pidfile — clean up
    rm -f "$PIDFILE"
fi

# Write our PID
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

# Poll loop
while true; do
    if [ -f "$URL_FILE" ]; then
        url=$(cat "$URL_FILE" 2>/dev/null)
        rm -f "$URL_FILE"
        if [ -n "$url" ]; then
            if echo "$url" | grep -qE '^https?://'; then
                open "$url" >/dev/null 2>&1
            else
                tmux display-message "Not a valid URL: $url"
            fi
        fi
    fi
    sleep "$POLL_INTERVAL"
done
