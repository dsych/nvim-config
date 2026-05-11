#!/usr/bin/env bash
# tmux-spotify.sh - Spotify currently playing for tmux status line
# Converted from wezterm.lua format_currently_playing()
# Usage: set -g status-right '#(~/tmux-spotify.sh)'
# Only works on macOS (uses osascript)

# Exit silently if not macOS
[[ "$(uname -s)" == "Darwin" ]] || exit 0

MAX_WIDTH=50

# Nerd Font icons (portable octal UTF-8)
ICON_PLAY=$(printf '\357\201\213')    # U+F04B fa-play
ICON_PAUSE=$(printf '\357\201\214')   # U+F04C fa-pause

query_spotify() {
    osascript -e "
tell application \"Spotify\"
    return $1
end tell" 2>/dev/null
}

# Check if Spotify is running
if ! pgrep -xq "Spotify"; then
    exit 0
fi

# Get player state
state=$(query_spotify "player state as string")
case "$state" in
    playing) icon="$ICON_PLAY " ;;
    paused)  icon="$ICON_PAUSE " ;;
    *)       exit 0 ;;
esac

# Get track name
track=$(query_spotify "current track's name")
[[ -z "$track" ]] && exit 0

# Truncate if needed
if [[ ${#track} -gt $MAX_WIDTH ]]; then
    track="${track:0:$MAX_WIDTH}…"
fi

printf "%s%s" "$icon" "$track"
