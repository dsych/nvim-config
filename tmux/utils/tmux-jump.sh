#!/usr/bin/env bash
# tmux-jump.sh - EasyMotion-style jump for tmux copy mode
# Redraws the window with the real pane layout and puts a letter hint on the
# start of every word in every visible pane. Typing a hint selects that pane,
# enters copy mode (if needed) and puts the copy-mode cursor on the word. An
# active selection is extended, so it also works as a quick selection motion.
#
# Hints are prefix-free: the words closest to the cursor get 1-letter hints,
# the rest 2 (or 3) letters. After the first letter only matching hints stay
# on screen. Esc cancels, Backspace undoes a letter.
#
# With --line the hints go on the start of every line instead (blank rows below
# the last text in a pane are skipped) and the cursor lands on column 0.
#
# Pane state is passed from the tmux binding (before the popup steals context).
# Usage: tmux-jump.sh [--line] <pane_id> <in_mode> <scroll_pos> <pane_height> <zoomed>
#
# The binding runs this script directly (it is the launcher): it captures the
# panes (before the popup opens; see hint_save_capture in tmux-hint-lib.sh),
# opens itself in a popup (--pick) to choose a target, and once the popup is
# gone applies the jump. Applying must wait for the popup to close: in recent
# tmux the popup is a pane, and closing it re-focuses the pane that was active
# when it opened, undoing any select-pane done from inside it.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tmux-hint-lib.sh
. "$SCRIPT_DIR/tmux-hint-lib.sh"

mode=word
[ "${1:-}" = "--line" ] && { mode=line; shift; }

jump_apply() {
    local pid="$1" row="$2" col="$3" caller="$4" rect
    # Enter copy mode unless the pane is already in it (view-mode is copy mode too)
    case "$(tmux display-message -p -t "$pid" '#{pane_mode}')" in
        copy-mode|view-mode) ;;
        *) tmux copy-mode -t "$pid" ;;
    esac
    # With a rectangle selection, cursor-right runs to the pane edge instead of
    # the end of the text
    rect=$(tmux display-message -p -t "$pid" '#{rectangle_toggle}')
    [ "$rect" = "1" ] && tmux send-keys -t "$pid" -X rectangle-off
    # top-line is exactly row 0, column 0 of the view. cursor-down then keeps
    # that column, so the cursor reaches column 0 of the target row whatever
    # the row lengths (wrapped rows included); cursor-right steps one character
    # at a time (wide characters and tabs are one step) along the row.
    tmux send-keys -t "$pid" -X top-line
    [ "$row" -gt 0 ] && tmux send-keys -t "$pid" -X -N "$row" cursor-down
    [ "$col" -gt 0 ] && tmux send-keys -t "$pid" -X -N "$col" cursor-right
    [ "$rect" = "1" ] && tmux send-keys -t "$pid" -X rectangle-on
    # Move the cursor line (tmux-copy-cursorline.sh) to the new position
    [ "$(tmux show-options -gqv @copy-cursorline)" != "off" ] && tmux send-keys -t "$pid" -X set-mark
    # Show/hide the URL of a hyperlink under the new position (tmux-link-peek.sh)
    [ "$(tmux show-options -gqv @link-peek)" != "off" ] && "$SCRIPT_DIR/tmux-link-peek.sh" update "$pid"
    # Select the pane last: focus hooks may resize it, and the cursor must
    # already be on the word by then (copy mode keeps the cursor on the same
    # text across a resize)
    [ "$pid" != "$caller" ] && tmux select-pane -t "$pid"
    return 0
}

# Launcher (what the binding runs): capture, run the picker in a popup, and
# apply its choice once the popup has closed
if [ "${1:-}" != "--pick" ]; then
    caller_pane="${1:-}"; caller_zoomed="${5:-0}"
    work_dir=$(mktemp -d)
    trap 'rm -rf "$work_dir"' EXIT
    # No popup exists yet, so no pane may be skipped as "the picker's own"
    # (run-shell can inherit an unrelated TMUX_PANE from the server)
    unset TMUX_PANE
    hint_capture_window "$caller_pane" "${2:-0}" "${3:-0}" "${4:-24}" "$caller_zoomed" "$work_dir"
    [ -z "$content" ] && exit 0
    hint_save_capture "$work_dir"
    # Caller's cursor in window coordinates: hints are handed out nearest first
    read -r cur_left cur_top cur_x cur_y < <(tmux display-message -p -t "$caller_pane" \
        '#{pane_left} #{pane_top} #{?pane_in_mode,#{copy_cursor_x},#{cursor_x}} #{?pane_in_mode,#{copy_cursor_y},#{cursor_y}}')
    [ "$caller_zoomed" = "1" ] && cur_left=0 cur_top=0
    printf '%s %s %s %s\n' "$cur_left" "$cur_top" "$cur_x" "$cur_y" > "$work_dir/cursor"
    result_file="$work_dir/result"
    self_args=("${BASH_SOURCE[0]}" --pick)
    [ "$mode" = "line" ] && self_args+=(--line)
    printf -v popup_cmd '%q ' "${self_args[@]}" "$work_dir"
    tmux display-popup -B -w 100% -h 100% -E "$popup_cmd"
    [ -s "$result_file" ] || exit 0
    IFS=$'\t' read -r pid row col < "$result_file"
    jump_apply "$pid" "$row" "$col" "$caller_pane"
    exit 0
fi
shift   # --pick
[ "${1:-}" = "--line" ] && { mode=line; shift; }

# The launcher owns (and removes) the work dir
work_dir="${1:?work dir}"
result_file="$work_dir/result"
hint_load_capture "$work_dir"
[ -z "$content" ] && exit 0
read -r cur_left cur_top cur_x cur_y < "$work_dir/cursor"

# 1. Every word start (or line start), as: distance, pane, row, column.
targets_file="$work_dir/targets"
"$AWK" -v GEOM="$geom_file" -v CY="$((cur_top + cur_y))" -v CX="$((cur_left + cur_x))" -v MODE="$mode" '
function target(row, col,    i, y, x) {
    # Skip text of a tiled pane hidden under a floating pane (box included)
    if (!floating) {
        y = top + row; x = left + col
        for (i = 1; i <= nf; i++)
            if (y >= fy1[i] && y <= fy2[i] && x >= fx1[i] && x <= fx2[i]) return
    }
    # Rows are about twice as tall as columns are wide
    dy = (top + row - CY) * 2; dx = left + col - CX
    printf "%d\t%s\t%d\t%d\n", dy * dy + dx * dx, pid, row, col
}
BEGIN {
    while ((getline g < GEOM) > 0) {
        split(g, f, "\t")
        if (f[7] != "1") continue
        nf++; fx1[nf] = f[1] - 1; fy1[nf] = f[2] - 1; fx2[nf] = f[1] + f[3]; fy2[nf] = f[2] + f[4]
    }
    close(GEOM)
    while ((getline g < GEOM) > 0) {
        split(g, f, "\t")
        left = f[1] + 0; top = f[2] + 0; ph = f[4] + 0; file = f[5]; pid = f[6]; floating = (f[7] == "1")
        n = 0; last = -1
        while (n < ph && (getline line < file) > 0) {
            rows[n] = line
            if (line ~ /[^[:space:]]/) last = n
            n++
        }
        close(file)
        for (row = 0; row < n; row++) {
            line = rows[row]
            if (MODE == "line") {
                if (row <= last) target(row, 0)
            } else {
                rest = line; off = 0
                while (match(rest, /[[:alnum:]_]+/)) {
                    target(row, off + RSTART - 1)
                    off += RSTART + RLENGTH - 1
                    rest = substr(rest, RSTART + RLENGTH)
                }
            }
        }
    }
}' | sort -n -k1,1 | "$AWK" -F'\t' -v ALPHA="$ALPHABET" '
# 2. Prefix-free hints, shortest (home-row first) for the nearest targets
{ t[NR] = $2 "\t" $3 "\t" $4 }
END {
    N = NR; A = length(ALPHA)
    for (i = 1; i <= A; i++) c[i] = substr(ALPHA, i, 1)
    n = 0
    if (N <= A) {
        for (i = 1; i <= N; i++) h[++n] = c[i]
    } else if (N <= A * A) {
        # k single letters; the remaining letters become 2-letter prefixes
        k = int((A * A - N) / (A - 1))
        for (i = 1; i <= k; i++) h[++n] = c[i]
        for (i = k + 1; i <= A; i++) for (j = 1; j <= A; j++) h[++n] = c[i] c[j]
    } else {
        # m of the 2-letter hints become 3-letter prefixes
        m = int((N - A * A + A - 2) / (A - 1)); if (m > A * A) m = A * A
        for (i = 1; i <= A; i++) for (j = 1; j <= A; j++) d[++nd] = c[i] c[j]
        for (i = 1; i <= nd - m; i++) h[++n] = d[i]
        for (i = nd - m + 1; i <= nd; i++) for (j = 1; j <= A; j++) h[++n] = d[i] c[j]
    }
    for (i = 1; i <= N && i <= n; i++) print h[i] "\t" t[i]
}' > "$targets_file"

if [ ! -s "$targets_file" ]; then
    tmux display-message "No ${mode}s to jump to"
    exit 0
fi

hint_canvas_size

# Draw the window dimmed, with hints (minus the letters already typed) on top
render() {
    "$AWK" -v W="$canvas_w" -v H="$canvas_h" -v GEOM="$geom_file" -v TARGETS="$targets_file" -v TYPED="$1" -v MODE="$mode" "$HINT_DRAW_AWK"'
    function annotate(line, pane_id, row,    key, cnt, i, out, cur, pos, h, hl, skip) {
        key = pane_id SUBSEP row
        cnt = nt[key] + 0
        if (cnt == 0) return DIM line RESET
        # Line mode: one hint at column 0, drawn over the finished row (save
        # cursor, row, restore, hint). Replacing the first characters instead
        # would shift the rest of the row when the hint covers a tab or a wide
        # character.
        if (MODE == "line") return "\0337" DIM line RESET "\0338" HINT thint[key, 1] RESET
        out = DIM; cur = 1
        for (i = 1; i <= cnt; i++) {
            pos = tcol[key, i] + 1; h = thint[key, i]; hl = length(h)
            skip = 0
            if (pos < cur) { skip = cur - pos; pos = cur }   # overlaps the previous hint
            out = out substr(line, cur, pos - cur) HINT substr(h, skip + 1) RESET DIM
            cur = pos + hl - skip
        }
        return out substr(line, cur) RESET
    }
    BEGIN {
        DIM = "\033[90m"
        tl = length(TYPED)
        while ((getline t < TARGETS) > 0) {
            split(t, f, "\t")
            if (substr(f[1], 1, tl) != TYPED) continue
            key = f[2] SUBSEP f[3]
            # targets come in distance order; keep each row sorted by column
            i = ++nt[key]
            while (i > 1 && tcol[key, i - 1] > f[4] + 0) {
                tcol[key, i] = tcol[key, i - 1]; thint[key, i] = thint[key, i - 1]; i--
            }
            tcol[key, i] = f[4] + 0; thint[key, i] = substr(f[1], tl + 1)
        }
        close(TARGETS)
        draw_window()
    }'
}

typed=""
selected=""
label=Word; [ "$mode" = "line" ] && label=Line
while :; do
    render "$typed"
    printf '\033[7m %s jump — type hint%s (Esc cancel, Backspace undo) \033[0m' "$label" "${typed:+: $typed}"
    IFS= read -rsn1 k || exit 0
    case "$k" in
        ""|$'\x1b') exit 0 ;;
        $'\x7f'|$'\b') typed="${typed%?}"; continue ;;
    esac
    try="$typed$k"
    selected=$("$AWK" -F'\t' -v t="$try" '$1 == t { print; exit }' "$targets_file")
    [ -n "$selected" ] && break
    # Keep the letter only if some hint still starts with it; ignore typos
    if "$AWK" -F'\t' -v t="$try" 'index($1, t) == 1 { found = 1; exit } END { exit !found }' "$targets_file"; then
        typed="$try"
    fi
done

# Hand the choice to the launcher, which applies it after the popup closes
IFS=$'\t' read -r _ pid row col <<< "$selected"
printf '%s\t%s\t%s\n' "$pid" "$row" "$col" > "$result_file"
exit 0
