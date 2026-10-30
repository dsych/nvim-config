#!/usr/bin/env bash
# Copy stdin to a tmux buffer and the appropriate clipboard. Preserve bytes,
# including trailing newlines. Remote uses OSC 52, never the remote desktop.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/tmux-action-lib.sh"

file=$(mktemp "${TMPDIR:-/tmp}/tmux-copy.XXXXXX") || exit 1
trap 'rm -f "$file"' EXIT
cat > "$file" || exit 1

native=0
if [ "$(action_environment)" = local ]; then
    case "$(uname -s)" in
        Darwin)
            if command -v pbcopy >/dev/null 2>&1 && pbcopy < "$file"; then native=1; fi ;;
        Linux)
            if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1 && wl-copy < "$file"; then
                native=1
            elif [ -n "${DISPLAY:-}" ]; then
                if command -v xclip >/dev/null 2>&1 && xclip -selection clipboard -in < "$file"; then
                    native=1
                elif command -v xsel >/dev/null 2>&1 && xsel --clipboard --input < "$file"; then
                    native=1
                fi
            fi ;;
    esac
fi
# Native success: don't send a second clipboard write through the terminal.
# Missing/failed native tool (or SSH): OSC 52 retains the previous behaviour.
if [ "$native" = 1 ]; then
    tmux load-buffer "$file"
else
    tmux load-buffer -w "$file"
fi
