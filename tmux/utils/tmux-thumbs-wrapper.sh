#!/usr/bin/env bash
# tmux-thumbs-wrapper.sh - Vimium-style hint picker for tmux
# Captures pane content (all panes or zoomed pane), highlights patterns with letter hints.
# Full-window popup overlay. Supports multi-character hints for >26 matches.
# Pane state is passed from the tmux binding (before popup steals context).
# Usage: tmux-thumbs-wrapper.sh [copy|open] <pane_id> <in_mode> <scroll_pos> <pane_height> <zoomed>

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
action="${1:-copy}"
caller_pane="${2:-}"
caller_in_mode="${3:-0}"
caller_scroll_pos="${4:-0}"
caller_height="${5:-24}"
caller_zoomed="${6:-0}"

ALPHABET="asdfghjklqwertyuiopzxcvbnm"
ALPHA_LEN=${#ALPHABET}

# Capture a single pane, respecting copy-mode scroll position
capture_pane() {
    local pid="$1" in_mode="$2" scroll_pos="$3" height="$4"
    if [ "$in_mode" = "1" ] && [ "$scroll_pos" -gt 0 ] 2>/dev/null; then
        local start=$(( -scroll_pos ))
        local end=$(( -scroll_pos + height - 1 ))
        tmux capture-pane -p -t "$pid" -S "$start" -E "$end" 2>/dev/null
    else
        tmux capture-pane -p -t "$pid" 2>/dev/null
    fi
}

# Generate hint string for index N
generate_hint() {
    local idx=$1 hint_len=$2
    if [ "$hint_len" -eq 1 ]; then
        echo "${ALPHABET:$idx:1}"
    else
        local first=$((idx / ALPHA_LEN))
        local second=$((idx % ALPHA_LEN))
        echo "${ALPHABET:$first:1}${ALPHABET:$second:1}"
    fi
}

# Capture pane content
content=""
if [ "$caller_zoomed" = "1" ]; then
    content=$(capture_pane "$caller_pane" "$caller_in_mode" "$caller_scroll_pos" "$caller_height")
else
    while IFS=$'\t' read -r pid; do
        if [ "$pid" = "$caller_pane" ]; then
            pane_content=$(capture_pane "$pid" "$caller_in_mode" "$caller_scroll_pos" "$caller_height")
        else
            pane_content=$(tmux capture-pane -p -t "$pid" 2>/dev/null)
        fi
        if [ -n "$pane_content" ]; then
            [ -n "$content" ] && content+=$'\n'
            content+="$pane_content"
        fi
    done < <(tmux list-panes -F '#{pane_id}' -t "$(tmux display-message -p -t "$caller_pane" '#{window_id}')")
fi

[ -z "$content" ] && exit 0

# Patterns by priority (earlier = gets shorter hints)
PAT_URLS='https?://[^ )>"'"'"']+'
PAT_SSH_GIT='ssh://[^ )>"'"'"']+|git@[a-zA-Z0-9._-]+:[^ )>"'"'"']+'
PAT_TICKETS='(CR|SIM|NKILIB|TT)-[0-9]+|[VP][0-9]{6,}'
PAT_ARNS='arn:aws:[a-zA-Z0-9:/_.*-]+'
PAT_FILE_LINE='[a-zA-Z0-9._/-]+\.[a-zA-Z]{1,10}:[0-9]+(:[0-9]+)?'
PAT_REL_PATHS='\.{0,2}/[a-zA-Z0-9._/-]{4,}'
PAT_ABS_PATHS='/[a-zA-Z0-9._/-]{4,}'
PAT_EMAILS='[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
PAT_VERSIONS='v?[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?'
PAT_SHAS='[a-f0-9]{7,40}'
PAT_UUIDS='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
PAT_AWS_ACCTS='[0-9]{12}'
PAT_IPS='[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?'
PAT_K8S='(pod|deploy|deployment|svc|service|ingress|configmap|secret|ns|namespace|job|cronjob|daemonset|statefulset|replicaset|pv|pvc)/[a-zA-Z0-9._-]+'
PAT_COLORS='#[a-fA-F0-9]{6}'
PAT_MACS='[0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5}'

mapfile -t raw_matches < <(
    {
        echo "$content" | grep -oE "$PAT_URLS"
        echo "$content" | grep -oE "$PAT_SSH_GIT"
        echo "$content" | grep -oE "$PAT_TICKETS"
        echo "$content" | grep -oE "$PAT_ARNS"
        echo "$content" | grep -oE "$PAT_FILE_LINE"
        echo "$content" | grep -oE "$PAT_REL_PATHS"
        echo "$content" | grep -oE "$PAT_ABS_PATHS"
        echo "$content" | grep -oE "$PAT_EMAILS"
        echo "$content" | grep -oE "$PAT_VERSIONS"
        echo "$content" | grep -oE "$PAT_SHAS"
        echo "$content" | grep -oE "$PAT_UUIDS"
        echo "$content" | grep -oE "$PAT_AWS_ACCTS"
        echo "$content" | grep -oE "$PAT_IPS"
        echo "$content" | grep -oE "$PAT_K8S"
        echo "$content" | grep -oE "$PAT_COLORS"
        echo "$content" | grep -oE "$PAT_MACS"
    } 2>/dev/null | awk '!seen[$0]++'
)

# Remove matches that are substrings of longer matches
mapfile -t matches < <(
    printf '%s\n' "${raw_matches[@]}" | awk '{
        lines[NR] = $0
    }
    END {
        for (i = 1; i <= NR; i++) {
            is_sub = 0
            for (j = 1; j <= NR; j++) {
                if (i != j && length(lines[j]) > length(lines[i]) && index(lines[j], lines[i]) > 0) {
                    is_sub = 1
                    break
                }
            }
            if (!is_sub) print lines[i]
        }
    }'
)

if [ ${#matches[@]} -eq 0 ]; then
    tmux display-message "No patterns found"
    exit 0
fi

num_matches=${#matches[@]}

# Determine hint length: 1 char for ≤26, 2 chars for >26
if [ "$num_matches" -le "$ALPHA_LEN" ]; then
    hint_len=1
else
    hint_len=2
fi

# Build hint→match mapping
declare -A hint_map
match_file=$(mktemp)
trap 'rm -f "$match_file"' EXIT

for i in "${!matches[@]}"; do
    h=$(generate_hint "$i" "$hint_len")
    hint_map["$h"]="${matches[$i]}"
    printf '%s\t%s\n' "$h" "${matches[$i]}" >> "$match_file"
done

# Annotate content: inject colored hint markers before each match
# Process longest matches first to prevent shorter matches from highlighting inside longer ones
annotated=$(awk '
BEGIN {
    while ((getline line < "'"$match_file"'") > 0) {
        split(line, parts, "\t")
        hint[++n] = parts[1]
        match_str[n] = parts[2]
        match_len[n] = length(parts[2])
    }
    # Sort by match length descending (bubble sort, small n)
    for (i = 1; i <= n; i++) {
        for (j = i + 1; j <= n; j++) {
            if (match_len[j] > match_len[i]) {
                tmp = hint[i]; hint[i] = hint[j]; hint[j] = tmp
                tmp = match_str[i]; match_str[i] = match_str[j]; match_str[j] = tmp
                tmp = match_len[i]; match_len[i] = match_len[j]; match_len[j] = tmp
            }
        }
    }
}
{
    line = $0
    shadow = $0  # tracks which positions are already highlighted
    for (i = 1; i <= n; i++) {
        idx = index(shadow, match_str[i])
        if (idx > 0) {
            m = match_str[i]
            h = hint[i]
            # Build replacement for display line
            pre = substr(line, 1, idx - 1)
            suf = substr(line, idx + length(m))
            replacement = "\033[1;43;30m" h "\033[0m\033[4;32m" m "\033[0m"
            line = pre replacement suf
            # Blank out matched region in shadow so nothing re-matches here
            blank = ""
            for (k = 1; k <= length(m); k++) blank = blank "\001"
            shadow = substr(shadow, 1, idx - 1) blank substr(shadow, idx + length(m))
            # Adjust line offset: replacement is longer than original
            offset = length(replacement) - length(m)
            # Shift shadow to keep in sync with line
            pad = ""
            for (k = 1; k <= offset; k++) pad = pad "\001"
            shadow = substr(shadow, 1, idx - 1 + length(blank)) pad substr(shadow, idx + length(blank))
        }
    }
    print line
}' <<< "$content")

# Display annotated content
clear
printf '%b\n' "$annotated"

# Status bar
if [ "$action" = "open" ]; then
    printf '\n\033[7m Open URL — press %d-char hint or Esc to cancel \033[0m' "$hint_len"
else
    printf '\n\033[7m Copy — press %d-char hint or Esc to cancel \033[0m' "$hint_len"
fi

# Read hint keypress(es)
read -rsn"$hint_len" key

# Escape key (first byte 0x1b)
[[ "$key" == $'\x1b'* ]] && exit 0
[ -z "$key" ] && exit 0

# Look up hint
selected="${hint_map[$key]}"
[ -z "$selected" ] && exit 0

case "$action" in
    copy) "$SCRIPT_DIR/tmux-copy-hint.sh" "$selected" ;;
    open) "$SCRIPT_DIR/tmux-open-url.sh" "$selected" ;;
esac
