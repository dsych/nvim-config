#!/usr/bin/env bash
# tmux-url-watcher.sh - Background daemon that watches ~/ssh_shared/.open_url
# and opens URLs in the local browser. Only one instance runs at a time.
# Launched by tmux.conf on local sessions (macOS or Linux desktops).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

PIDFILE="/tmp/tmux-url-watcher.pid"
URL_FILE="${TMUX_SSH_SHARED:-$HOME/ssh_shared}/.open_url"
POLL_INTERVAL=2

consume_url() {
    local url
    if [ -f "$URL_FILE" ]; then
        url=$(cat "$URL_FILE" 2>/dev/null)
        rm -f "$URL_FILE"
        [ -z "$url" ] || "$SCRIPT_DIR/tmux-open-url.sh" --local "$url"
    fi
}
# One-shot consumption is useful for checking the relay without a daemon.
if [ "${1:-}" = --once ]; then
    consume_url
    exit $?
fi

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
    consume_url
    sleep "$POLL_INTERVAL"
done
