#!/usr/bin/env bash
# Open locally via the OS, or relay to the client via ssh_shared over SSH.
# --local bypasses routing for the receiving watcher (no relay loop).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/tmux-action-lib.sh"

local_only=0
[ "${1:-}" = --local ] && { local_only=1; shift; }
url="${1:-}"
[ -n "$url" ] || exit 0
case "$url" in
    http://?*|https://?*) ;;
    *) action_notice "Not a valid HTTP/HTTPS URL: $url"; exit 1 ;;
esac
case "$url" in
    *$'\n'*|*$'\r'*) action_notice 'URL contains a line break'; exit 1 ;;
esac

if [ "$local_only" = 1 ] || [ "$(action_environment)" = local ]; then
    action_open_local "$url"
else
    shared="${TMUX_SSH_SHARED:-$HOME/ssh_shared}"
    mkdir -p "$shared" || exit 1
    file=$(mktemp "$shared/.open_url.XXXXXX") || exit 1
    trap 'rm -f "$file"' EXIT
    printf '%s\n' "$url" > "$file" && mv -f "$file" "$shared/.open_url" || exit 1
    tmux display-message -l "Opening on local: $url"
fi
