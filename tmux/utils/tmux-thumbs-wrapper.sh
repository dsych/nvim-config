#!/usr/bin/env bash
# tmux-thumbs-wrapper.sh - Vimium-style hint picker for tmux
# Captures pane content (all panes or zoomed pane), redraws them with the real
# window layout, and overlays letter hints on matched patterns.
# Full-window popup overlay (borderless). Supports multi-character hints for >26 matches.
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

# Prefer gawk (UTF-8 aware: pads/cuts by character, not byte), fall back to awk
AWK=$(command -v gawk || command -v awk)
# Character-aware string ops need a UTF-8 locale
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) ;;
    *) export LC_ALL=C.UTF-8 ;;
esac

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

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

# Capture every visible pane of the caller's window along with its geometry so
# the overlay can be rebuilt with the real window layout (side-by-side panes
# stay side by side), regardless of which pane triggered the picker.
window_id=$(tmux display-message -p -t "$caller_pane" '#{window_id}')
read -r win_w win_h < <(tmux display-message -p -t "$caller_pane" '#{window_width} #{window_height}')
geom_file="$work_dir/geometry"
: > "$geom_file"
content=""
while IFS=$'\t' read -r pid left top width height; do
    if [ "$caller_zoomed" = "1" ]; then
        # Only the zoomed pane is visible; it fills the whole window
        [ "$pid" = "$caller_pane" ] || continue
        left=0 top=0 width=$win_w height=$win_h
    fi
    if [ "$pid" = "$caller_pane" ]; then
        pane_content=$(capture_pane "$pid" "$caller_in_mode" "$caller_scroll_pos" "$caller_height")
    else
        pane_content=$(tmux capture-pane -p -t "$pid" 2>/dev/null)
    fi
    pane_file="$work_dir/pane${pid#%}"
    printf '%s\n' "$pane_content" > "$pane_file"
    printf '%s\t%s\t%s\t%s\t%s\n' "$left" "$top" "$width" "$height" "$pane_file" >> "$geom_file"
    if [ -n "$pane_content" ]; then
        [ -n "$content" ] && content+=$'\n'
        content+="$pane_content"
    fi
done < <(tmux list-panes -t "$window_id" -F '#{pane_id}	#{pane_left}	#{pane_top}	#{pane_width}	#{pane_height}')

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
match_file="$work_dir/matches"
: > "$match_file"

for i in "${!matches[@]}"; do
    h=$(generate_hint "$i" "$hint_len")
    hint_map["$h"]="${matches[$i]}"
    printf '%s\t%s\n' "$h" "${matches[$i]}" >> "$match_file"
done

# Popup size: the canvas is clipped to it, keeping the last row for the prompt
read -r term_rows term_cols < <(stty size < /dev/tty 2>/dev/null)
canvas_w=$win_w; canvas_h=$win_h
[ -n "$term_cols" ] && [ "$term_cols" -lt "$canvas_w" ] && canvas_w=$term_cols
[ -n "$term_rows" ] && [ "$term_rows" -le "$canvas_h" ] && canvas_h=$((term_rows - 1))

# Redraw every pane at its real position in the window (cursor addressing, so
# wide characters can't push columns around), draw the pane borders, and
# overlay hints on the first characters of each match. Overlaying instead of
# inserting keeps every column exactly where it is in the real window.
render() {
    "$AWK" -v W="$canvas_w" -v H="$canvas_h" -v GEOM="$geom_file" -v MATCHES="$match_file" '
    function at(y, x, s) { if (y < H && x < W) printf "\033[%d;%dH%s", y + 1, x + 1, s }
    function annotate(line,    shadow, ns, i, j, t, from, p, pos, mask, out, cur, l, h, hl) {
        shadow = line; ns = 0
        delete seg_pos; delete seg_len; delete seg_hint
        for (i = 1; i <= n; i++) {
            from = 1
            while ((p = index(substr(shadow, from), str[i])) > 0) {
                pos = from + p - 1
                ns++; seg_pos[ns] = pos; seg_len[ns] = len[i]; seg_hint[ns] = hint[i]
                mask = sprintf("%" len[i] "s", ""); gsub(/ /, "\001", mask)
                shadow = substr(shadow, 1, pos - 1) mask substr(shadow, pos + len[i])
                from = pos + len[i]
            }
        }
        for (i = 1; i <= ns; i++)
            for (j = i + 1; j <= ns; j++)
                if (seg_pos[j] < seg_pos[i]) {
                    t = seg_pos[i];  seg_pos[i]  = seg_pos[j];  seg_pos[j]  = t
                    t = seg_len[i];  seg_len[i]  = seg_len[j];  seg_len[j]  = t
                    t = seg_hint[i]; seg_hint[i] = seg_hint[j]; seg_hint[j] = t
                }
        out = ""; cur = 1
        for (i = 1; i <= ns; i++) {
            pos = seg_pos[i]; l = seg_len[i]; h = seg_hint[i]; hl = length(h)
            out = out substr(line, cur, pos - cur)
            if (l > hl) out = out HINT h RESET REST substr(line, pos + hl, l - hl) RESET
            else        out = out HINT substr(h, 1, l) RESET
            cur = pos + l
        }
        return out substr(line, cur)
    }
    BEGIN {
        HINT = "\033[1;43;30m"; REST = "\033[4;32m"; RESET = "\033[0m"
        n = 0
        while ((getline m < MATCHES) > 0) {
            split(m, f, "\t")
            n++; hint[n] = f[1]; str[n] = f[2]; len[n] = length(f[2])
        }
        close(MATCHES)
        # Longest first so shorter matches never land inside longer ones
        for (i = 1; i <= n; i++)
            for (j = i + 1; j <= n; j++)
                if (len[j] > len[i]) {
                    t = hint[i]; hint[i] = hint[j]; hint[j] = t
                    t = str[i];  str[i]  = str[j];  str[j]  = t
                    t = len[i];  len[i]  = len[j];  len[j]  = t
                }

        printf "\033[?7l"   # no autowrap: clipped lines must not spill into the next row
        while ((getline g < GEOM) > 0) {
            split(g, f, "\t")
            left = f[1] + 0; top = f[2] + 0; pw = f[3] + 0; ph = f[4] + 0; file = f[5]
            for (i = 0; i < ph; i++) {
                if ((getline line < file) <= 0) break
                if (line != "") at(top + i, left, annotate(line))
            }
            close(file)
            # Border cells: column right of the pane, row below it
            if (left + pw < W) for (i = 0; i < ph; i++) vb[top + i, left + pw] = 1
            if (top + ph < H)  for (i = 0; i < pw; i++) hb[top + ph, left + i] = 1
        }
        close(GEOM)
        # Borders, with junctions where they meet, like tmux draws them
        for (k in hb) {
            split(k, yx, SUBSEP); y = yx[1] + 0; x = yx[2] + 0
            up = ((y - 1, x) in vb); dn = ((y + 1, x) in vb)
            at(y, x, (up && dn) ? "┼" : dn ? "┬" : up ? "┴" : "─")
        }
        for (k in vb) {
            split(k, yx, SUBSEP); y = yx[1] + 0; x = yx[2] + 0
            if ((y, x) in hb) continue
            lt = ((y, x - 1) in hb); rt = ((y, x + 1) in hb)
            at(y, x, (lt && rt) ? "┼" : rt ? "├" : lt ? "┤" : "│")
        }
        printf "\033[%d;1H\033[?7h", H + 1
    }'
}

# Display annotated window
clear
render

# Status bar
if [ "$action" = "open" ]; then
    printf '\033[7m Open URL — press %d-char hint or Esc to cancel \033[0m' "$hint_len"
else
    printf '\033[7m Copy — press %d-char hint or Esc to cancel \033[0m' "$hint_len"
fi

# Read hint keypress(es) one at a time so Esc cancels immediately, even for
# 2-char hints
key=""
while [ "${#key}" -lt "$hint_len" ]; do
    read -rsn1 k || exit 0
    [[ -z "$k" || "$k" == $'\x1b' ]] && exit 0
    key+="$k"
done

# Look up hint
selected="${hint_map[$key]}"
[ -z "$selected" ] && exit 0

case "$action" in
    copy) "$SCRIPT_DIR/tmux-copy-hint.sh" "$selected" ;;
    open) "$SCRIPT_DIR/tmux-open-url.sh" "$selected" ;;
esac
