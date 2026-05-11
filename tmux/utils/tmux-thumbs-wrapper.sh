#!/usr/bin/env bash
# tmux-thumbs-wrapper.sh - Vimium-style hint picker for tmux
# Captures ALL panes in the window, highlights patterns with letter hints.
# Full-window popup overlay, single keypress selects.
# Usage: tmux-thumbs-wrapper.sh [copy|open]

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
action="${1:-copy}"

# Capture pane content — if zoomed, only the active pane; otherwise all panes
content=""
zoomed=$(tmux display-message -p '#{window_zoomed_flag}')
if [ "$zoomed" = "1" ]; then
    content=$(tmux capture-pane -p 2>/dev/null)
else
    while read -r pid; do
        pane_content=$(tmux capture-pane -p -t "$pid" 2>/dev/null)
        if [ -n "$pane_content" ]; then
            [ -n "$content" ] && content+=$'\n'
            content+="$pane_content"
        fi
    done < <(tmux list-panes -F '#{pane_id}')
fi

[ -z "$content" ] && exit 0

# Pattern: URLs, file paths, git SHAs, IPs, UUIDs, hex colors, 4+ digit numbers
PATTERN='https?://[^ )>"'"'"']+|/[a-zA-Z0-9._/-]{4,}|[a-f0-9]{7,40}|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|#[a-fA-F0-9]{6}|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'

# Deduplicate matches preserving order, limit to 26 (a-z)
mapfile -t matches < <(echo "$content" | grep -oE "$PATTERN" | awk '!seen[$0]++' | head -26)

if [ ${#matches[@]} -eq 0 ]; then
    tmux display-message "No patterns found"
    exit 0
fi

HINTS="asdfghjklqwertyuiopzxcvbnm"

# Build hint→match mapping file for awk
match_file=$(mktemp)
trap 'rm -f "$match_file"' EXIT

for i in "${!matches[@]}"; do
    printf '%s\t%s\n' "${HINTS:$i:1}" "${matches[$i]}" >> "$match_file"
done

# Annotate content: inject colored [hint] markers before each match
annotated=$(awk '
BEGIN {
    while ((getline line < "'"$match_file"'") > 0) {
        split(line, parts, "\t")
        hint[++n] = parts[1]
        match_str[n] = parts[2]
    }
}
{
    line = $0
    for (i = 1; i <= n; i++) {
        idx = index(line, match_str[i])
        if (idx > 0) {
            m = match_str[i]
            h = hint[i]
            pre = substr(line, 1, idx - 1)
            suf = substr(line, idx + length(m))
            line = pre "\033[1;43;30m" h "\033[0m\033[4;32m" m "\033[0m" suf
        }
    }
    print line
}' <<< "$content")

# Display annotated content in the terminal and wait for keypress
clear
printf '%b\n' "$annotated"

# Status bar
active_hints="${HINTS:0:${#matches[@]}}"
if [ "$action" = "open" ]; then
    printf '\n\033[7m Open URL — press hint [%s] or Esc to cancel \033[0m' "$active_hints"
else
    printf '\n\033[7m Copy — press hint [%s] or Esc to cancel \033[0m' "$active_hints"
fi

# Read single keypress
read -rsn1 key

# Escape key
[ "$key" = $'\x1b' ] && exit 0
[ -z "$key" ] && exit 0

# Look up the match for this hint
selected=""
for i in "${!matches[@]}"; do
    if [ "${HINTS:$i:1}" = "$key" ]; then
        selected="${matches[$i]}"
        break
    fi
done

[ -z "$selected" ] && exit 0

case "$action" in
    copy) "$SCRIPT_DIR/tmux-copy-hint.sh" "$selected" ;;
    open) "$SCRIPT_DIR/tmux-open-url.sh" "$selected" ;;
esac
