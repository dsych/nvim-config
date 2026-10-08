#!/usr/bin/env bash
# tmux-thumbs-wrapper.sh - Vimium-style hint picker for tmux
# Captures pane content (all panes or zoomed pane), redraws them with the real
# window layout, and overlays letter hints on matched patterns.
# Full-window popup overlay (borderless). Supports multi-character hints for >26 matches.
# Pane state is passed from the tmux binding (before popup steals context).
# Usage: tmux-thumbs-wrapper.sh [copy|open] <pane_id> <in_mode> <scroll_pos> <pane_height> <zoomed>
#
# The binding runs this script directly (it is the launcher): it captures the
# panes first, then opens itself in a popup (--pick) that only draws and reads
# the hint. See hint_save_capture in tmux-hint-lib.sh for why the capture must
# happen before the popup opens.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tmux-hint-lib.sh
. "$SCRIPT_DIR/tmux-hint-lib.sh"

# Launcher: capture, then show the picker in a popup
if [ "${1:-}" != "--pick" ]; then
    action="${1:-copy}"
    work_dir=$(mktemp -d)
    trap 'rm -rf "$work_dir"' EXIT
    # A terminal on stdin means we already run in a popup (old binding that
    # wraps this in display-popup, or run by hand): pick in place, a popup
    # can't open another one. Otherwise (run-shell) no popup exists yet, so no
    # pane may be skipped as "the picker's own" (run-shell can inherit an
    # unrelated TMUX_PANE from the server).
    in_popup=0; [ -t 0 ] && in_popup=1
    [ "$in_popup" = 1 ] || unset TMUX_PANE
    hint_capture_window "${2:-}" "${3:-0}" "${4:-0}" "${5:-24}" "${6:-0}" "$work_dir"
    [ -z "$content" ] && exit 0
    hint_save_capture "$work_dir"
    if [ "$in_popup" = 1 ]; then
        "${BASH_SOURCE[0]}" --pick "$action" "$work_dir"
        exit 0
    fi
    printf -v popup_cmd '%q ' "${BASH_SOURCE[0]}" --pick "$action" "$work_dir"
    tmux display-popup -B -w 100% -h 100% -E "$popup_cmd"
    exit 0
fi

action="${2:-copy}"
work_dir="${3:?work dir}"

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

# The launcher owns (and removes) the work dir
hint_load_capture "$work_dir"

[ -z "$content" ] && exit 0

# Patterns by priority (earlier = gets shorter hints)
PAT_URLS='https?://[^ )>"'"'"']+'
PAT_SSH_GIT='ssh://[^ )>"'"'"']+|git@[a-zA-Z0-9._-]+:[^ )>"'"'"']+'
PAT_TICKETS='(CR|SIM|NKILIB|TT)-[0-9]+|[VP][0-9]{6,}'
# Prefixed UUID IDs, e.g. T_577e25c8-c6ff-46ed-9f9b-46fc64d150fb
PAT_PREFIXED_UUIDS='[A-Za-z]+_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
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

# Read lines into arrays with while-read loops, not mapfile/declare -A, so this
# runs on macOS's stock bash 3.2 too. Empty lines are dropped.
raw_matches=()
while IFS= read -r m; do
    [ -n "$m" ] && raw_matches[${#raw_matches[@]}]="$m"
done < <(
    {
        echo "$content" | grep -oE "$PAT_URLS"
        echo "$content" | grep -oE "$PAT_SSH_GIT"
        echo "$content" | grep -oE "$PAT_TICKETS"
        echo "$content" | grep -oE "$PAT_PREFIXED_UUIDS"
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

if [ ${#raw_matches[@]} -eq 0 ]; then
    tmux display-message "No patterns found"
    exit 0
fi

# Remove matches that are substrings of longer matches
matches=()
while IFS= read -r m; do
    [ -n "$m" ] && matches[${#matches[@]}]="$m"
done < <(
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
hints=()
match_file="$work_dir/matches"
: > "$match_file"

for i in "${!matches[@]}"; do
    h=$(generate_hint "$i" "$hint_len")
    hints[$i]="$h"
    printf '%s\t%s\n' "$h" "${matches[$i]}" >> "$match_file"
done

# Popup size: the canvas is clipped to it, keeping the last row for the prompt
hint_canvas_size

# Redraw every pane at its real position in the window (cursor addressing, so
# wide characters can't push columns around), draw the pane borders, and
# overlay hints on the first characters of each match. Overlaying instead of
# inserting keeps every column exactly where it is in the real window.
render() {
    "$AWK" -v W="$canvas_w" -v H="$canvas_h" -v GEOM="$geom_file" -v MATCHES="$match_file" "$HINT_DRAW_AWK"'
    function annotate(line, pane_id, row,    shadow, ns, i, j, t, from, p, pos, mask, out, cur, l, h, hl) {
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
        REST = "\033[4;32m"
        n = 0
        while ((getline m < MATCHES) > 0) {
            split(m, f, "\t")
            if (f[2] == "") continue   # an empty match would never advance the scan
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

        draw_window()
    }'
}

# Display annotated window
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
selected=""
for i in "${!hints[@]}"; do
    if [ "${hints[$i]}" = "$key" ]; then
        selected="${matches[$i]}"
        break
    fi
done
[ -z "$selected" ] && exit 0

case "$action" in
    copy) "$SCRIPT_DIR/tmux-copy-hint.sh" "$selected" ;;
    open) "$SCRIPT_DIR/tmux-open-url.sh" "$selected" ;;
esac
