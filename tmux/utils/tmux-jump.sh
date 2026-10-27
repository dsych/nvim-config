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
#
# The hinted text can move before the jump is applied, so the jump goes to the
# text, not to the row number it was hinted on:
#   * In a zoomed window, opening and closing the popup (a floating pane)
#     unzooms and re-zooms the window: the zoomed pane is resized twice each
#     time, and TUIs redraw. pi redraws everything on a resize, which drops
#     the blank rows its normal updates leave under shrunk content: its text
#     moves down a row or two.
#   * The program may print more (pi streaming a reply).
#   * A pane already in copy mode may have its view moved: on a resize, copy
#     mode re-scrolls to put the cursor line at the top.
# So when a hint is chosen the picker puts the target pane in copy mode right
# away, while the popup still hides it (copy mode keeps a copy of the pane, so
# later redraws don't touch it), then the launcher finds the hinted row in that
# copy by content. It scrolls only if the row is no longer on screen (back to
# where it was hinted), or to give a pane that was in copy mode already its
# view back.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tmux-hint-lib.sh
. "$SCRIPT_DIR/tmux-hint-lib.sh"

mode=word
[ "${1:-}" = "--line" ] && { mode=line; shift; }

# Where is the hinted row now? stdin: `capture-pane -L` lines ("<n> <text>";
# n counts from the top of the screen area, negative in the history) around
# the view. CAP: the rows the hints were drawn on, ROW: the hinted row, OY: the
# view's scroll position. Prints "<n> <matched> <rows>": n of the hinted row,
# from the placement of CAP that matches the most of its <rows> non-blank rows
# (and the hinted row itself, unless it is blank), the nearest to no shift on
# a tie; <matched> rows match there. With no such placement, matched is 0 and
# n is where the row was hinted.
JUMP_LOCATE_AWK='
BEGIN { nc = 0; while ((getline l < CAP) > 0) cap[nc++] = l; close(CAP) }
{
    sp = index($0, " "); n = substr($0, 1, sp - 1) + 0
    cur[n] = substr($0, sp + 1)
    if (NR == 1) lo = n
    hi = n
}
END {
    base = -OY
    tgt = (ROW < nc) ? cap[ROW] : ""
    want = 0
    for (r = 0; r < nc; r++) if (cap[r] != "") want++
    if (NR == 0) { print base + ROW, 0, want; exit }
    best = base; bestscore = -1
    far = base - (lo - nc + 1); if (hi - base > far) far = hi - base
    # nearest first, so the first perfect placement is the answer
    for (k = 0; k <= far && bestscore < want; k++) {
        for (sign = 1; sign >= -1; sign -= 2) {
            if (k == 0 && sign < 0) continue
            s = base + sign * k
            if (s < lo - nc + 1 || s > hi) continue
            if (tgt != "" && (!((s + ROW) in cur) || cur[s + ROW] != tgt)) continue
            score = 0
            for (r = 0; r < nc; r++)
                if (cap[r] != "" && ((s + r) in cur) && cur[s + r] == cap[r]) score++
            if (score > bestscore) { best = s; bestscore = score }
            if (bestscore == want) break
        }
    }
    if (bestscore <= 0 && tgt == "") best = base   # a blank row: only its neighbours locate it
    print best + ROW, (bestscore > 0 ? bestscore : 0), want
}'

# Placing the cursor. stdin: the rows on screen. R: the target row, CAP/CROW:
# the captured rows and the hinted row, COL: the hinted character in it.
# Prints "<first> <steps>":
#   first  the first non-empty row at or above R. cursor-down keeps a
#          remembered column, and started from an empty row (column 0 there is
#          also the end of the row) it goes to the end of every row after it;
#          in copy mode already, the column can be one the user left. So the
#          cursor walks over the empty rows at the top with cursor-right (from
#          an empty row it wraps to the start of the next) and only then goes
#          down: from column 0 of a non-empty row, it stays in column 0.
#   steps  cursor-right steps along R to the hinted character: one per tmux
#          cell. tmux keeps zero-width characters (combining marks, the
#          variation selector in ⚠️, joiners, the rest of an emoji sequence,
#          the second half of a flag) in the cell of the character before
#          them, while the capture has one character per code point.
JUMP_PLACE_AWK='
function steps(s, n,    i, c, k, join, ri, isri) {
    k = 0; join = 0; ri = 0
    for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (k > 0 && (join || c ~ ZW)) { join = (c == ZWJ); continue }
        isri = (c >= RI1 && c <= RI2)
        if (k > 0 && isri && ri) { ri = 0; continue }
        k++; join = 0; ri = isri
    }
    return k
}
BEGIN {
    # UTF-8 in octal (the characters are invisible): combining marks (Latin and
    # others, Cyrillic, Hebrew, Arabic, Hangul vowels and final consonants,
    # extended, supplement, for symbols, half marks), zero-width spaces and
    # joiners, word joiner and invisible operators, variation selectors (and
    # their supplement), byte order mark, emoji skin tones, tag characters
    ZW = "^[\314\200-\315\257\322\203-\322\211\326\221-\326\275\330\220-\330\232\331\213-\331\237" \
         "\341\205\240-\341\207\277\341\252\260-\341\253\277\341\267\200-\341\267\277" \
         "\342\200\213-\342\200\217\342\201\240-\342\201\244\342\203\220-\342\203\277" \
         "\357\270\200-\357\270\217\357\270\240-\357\270\257\357\273\277" \
         "\360\237\217\273-\360\237\217\277\363\240\200\240-\363\240\201\277\363\240\204\200-\363\240\207\257]$"
    ZWJ = "\342\200\215"
    RI1 = "\360\237\207\246"; RI2 = "\360\237\207\277"   # regional indicators
    for (i = 0; (getline l < CAP) > 0; i++) if (i == CROW) hinted = l
    close(CAP)
}
{ rows[NR - 1] = $0 }
END {
    first = R
    for (i = 0; i < R; i++) if (rows[i] != "") { first = i; break }
    n = steps(hinted, COL)
    # The row changed after all (no exact match): stay on it
    if (rows[R] != hinted) { m = steps(rows[R], length(rows[R])); if (n > m - 1) n = (m > 0) ? m - 1 : 0 }
    print first, n
}'

# Put the target in copy mode now, from inside the popup: copy mode copies the
# pane, so the redraw that closing the popup triggers in a zoomed window can't
# change the text the jump lands on. Opening the popup there made TUIs redraw
# too (pi takes a few hundred ms for a long session): wait until most of the
# captured rows are back (a half-done redraw has only some) and no
# synchronized update is in progress, at most ~1.5 s (the text may really be
# gone). Without capture-pane -L (before tmux 3.7, where popups don't resize
# anything either) there is nothing to wait for.
jump_freeze() {
    local pid="$1" row="$2" cap="$3" zoomed="$4" sy span lines n=0 _n matched rows
    case "$(tmux display-message -p -t "$pid" '#{pane_mode}' 2>/dev/null)" in
        copy-mode|view-mode) return 0 ;;
    esac
    if [ "$zoomed" = "1" ]; then
        sy=$(tmux display-message -p -t "$pid" '#{pane_height}' 2>/dev/null)
        span=$(( ${sy:-24} * 3 > 300 ? ${sy:-24} * 3 : 300 ))
        while [ "$n" -lt 30 ]; do
            if [ "$(tmux display-message -p -t "$pid" '#{synchronized_output_flag}' 2>/dev/null)" != "1" ]; then
                lines=$(tmux capture-pane -p -L -t "$pid" -S "-$span" -E "$(( 2 * ${sy:-24} - 1 ))" 2>/dev/null) || break
                read -r _n matched rows < <(printf '%s\n' "$lines" |
                    "$AWK" -v CAP="$cap" -v ROW="$row" -v OY=0 "$JUMP_LOCATE_AWK")
                [ "$(( ${matched:-0} * 4 ))" -ge "$(( ${rows:-0} * 3 ))" ] && break
            fi
            n=$((n + 1))
            sleep 0.03
        done
    fi
    tmux copy-mode -t "$pid" 2>/dev/null
    return 0
}

jump_apply() {
    local pid="$1" row="$2" col="$3" caller="$4" cap="$5" was_copy="$6"
    local oy sy rect span t delta R first steps
    local -a keys
    # Enter copy mode unless the pane is already in it (view-mode is copy
    # mode too); normally the picker did that already (jump_freeze)
    case "$(tmux display-message -p -t "$pid" '#{pane_mode}' 2>/dev/null)" in
        copy-mode|view-mode) ;;
        *) tmux copy-mode -t "$pid" 2>/dev/null || return 0 ;;
    esac
    IFS=$'\t' read -r oy sy rect < <(tmux display-message -p -t "$pid" \
        '#{scroll_position}	#{pane_height}	#{rectangle_toggle}')
    oy=${oy:-0}
    # 1. Find the hinted row in copy mode's copy (and its history: a redraw or
    #    new output scrolls text up). Without capture-pane -L (before tmux
    #    3.7) it stays where it was hinted.
    span=$(( sy * 3 > 300 ? sy * 3 : 300 ))
    read -r t _ < <(tmux capture-pane -M -p -L -t "$pid" -S "$(( -oy - span ))" -E "$(( -oy + 2 * sy - 1 ))" 2>/dev/null |
        "$AWK" -v CAP="$cap" -v ROW="$row" -v OY="$oy" "$JUMP_LOCATE_AWK")
    t=${t:-$(( row - oy ))}
    # 2. Off screen now: scroll it back to the row it was hinted on. A pane
    #    that was in copy mode already gets its view back that way too (a
    #    resize re-scrolls copy mode to the cursor line). Scrolling down to the
    #    bottom must not leave copy mode, as copy-mode -e would.
    if [ "${was_copy:-0}" != "0" ] || [ "$t" -lt $(( -oy )) ] || [ "$t" -ge $(( -oy + sy )) ]; then
        delta=$(( row - t - oy ))
        if [ "$delta" -gt 0 ]; then
            tmux send-keys -t "$pid" -X -N "$delta" scroll-up
        elif [ "$delta" -lt 0 ]; then
            tmux send-keys -t "$pid" -X scroll-exit-off \; send-keys -t "$pid" -X -N "$(( -delta ))" scroll-down
        fi
        oy=$(tmux display-message -p -t "$pid" '#{scroll_position}')
    fi
    R=$(( t + oy ))
    [ "$R" -lt 0 ] && R=0
    [ "$R" -ge "$sy" ] && R=$(( sy - 1 ))
    # 3. Place the cursor (see JUMP_PLACE_AWK)
    read -r first steps < <({ tmux capture-pane -M -p -t "$pid" -S "$(( -oy ))" -E "$(( -oy + sy - 1 ))" 2>/dev/null ||
        tmux capture-pane -p -t "$pid" -S "$(( -oy ))" -E "$(( -oy + sy - 1 ))" 2>/dev/null; } |
        "$AWK" -v R="$R" -v CAP="$cap" -v CROW="$row" -v COL="$col" "$JUMP_PLACE_AWK")
    # With a rectangle selection, cursor-right runs to the pane edge instead of
    # the end of the text
    [ "$rect" = "1" ] && keys+=(send-keys -t "$pid" -X rectangle-off \;)
    keys+=(send-keys -t "$pid" -X top-line \;)
    [ "${first:-0}" -gt 0 ] && keys+=(send-keys -t "$pid" -X -N "$first" cursor-right \;)
    [ "$R" -gt "${first:-0}" ] && keys+=(send-keys -t "$pid" -X -N "$(( R - ${first:-0} ))" cursor-down \;)
    tmux "${keys[@]}"
    keys=()
    # The walk ends in column 0, except with a line selection, which puts the
    # cursor at an end of every row it moves to: it selects whole rows, so the
    # column doesn't matter then (and cursor-right from the end of the row
    # would go on to the next one)
    [ "${steps:-0}" -gt 0 ] && [ "$(tmux display-message -p -t "$pid" '#{copy_cursor_x}')" = "0" ] &&
        keys+=(send-keys -t "$pid" -X -N "$steps" cursor-right \;)
    [ "$rect" = "1" ] && keys+=(send-keys -t "$pid" -X rectangle-on \;)
    # Move the cursor line (tmux-copy-cursorline.sh) to the new position
    [ "$(tmux show-options -gqv @copy-cursorline)" != "off" ] && keys+=(send-keys -t "$pid" -X set-mark \;)
    [ "${#keys[@]}" -gt 0 ] && tmux "${keys[@]}"
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
    printf '%s\n' "$caller_zoomed" > "$work_dir/zoomed"
    result_file="$work_dir/result"
    self_args=("${BASH_SOURCE[0]}" --pick)
    [ "$mode" = "line" ] && self_args+=(--line)
    printf -v popup_cmd '%q ' "${self_args[@]}" "$work_dir"
    tmux display-popup -B -w 100% -h 100% -E "$popup_cmd"
    [ -s "$result_file" ] || exit 0
    IFS=$'\t' read -r pid row col < "$result_file"
    # Was the target in copy mode already when the hints were drawn?
    was_copy=$("$AWK" -F'\t' -v P="$pid" '$6 == P { print $8; exit }' "$geom_file")
    jump_apply "$pid" "$row" "$col" "$caller_pane" "$work_dir/pane${pid#%}" "$was_copy"
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
    function annotate(line, pane_id, row,    key, cnt, i, out) {
        key = pane_id SUBSEP row
        cnt = nt[key] + 0
        if (cnt == 0) return DIM line RESET
        # The hints go over the finished row: save the cursor, the row, then
        # per hint restore it, the text before the hint again and the hint.
        # The terminal itself so puts every hint on its cell, whatever the
        # widths of the characters before it, and a hint over a wide
        # character or a tab (or a short hint over a long one) cannot move
        # the rest of the row, as replacing characters in the row would.
        # Right to left: where a hint runs into the next one, the left one
        # stays whole.
        out = "\0337" DIM line RESET
        for (i = cnt; i >= 1; i--)
            out = out "\0338" DIM substr(line, 1, tcol[key, i]) HINT thint[key, i] RESET
        return out
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
jump_freeze "$pid" "$row" "$work_dir/pane${pid#%}" "$(cat "$work_dir/zoomed" 2>/dev/null)"
exit 0
