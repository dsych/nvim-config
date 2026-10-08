# tmux-hint-lib.sh - shared helpers for the full-window hint pickers
# (tmux-thumbs-wrapper.sh, tmux-jump.sh). Source it; don't run it.
#
# Provides:
#   hint_capture_window <caller_pane> <in_mode> <scroll_pos> <height> <zoomed> <work_dir>
#       Captures every visible pane of the caller's window and writes
#       $work_dir/geometry: one line per pane,
#       left<TAB>top<TAB>width<TAB>height<TAB>capture_file<TAB>pane_id<TAB>floating
#       Floating panes come last (they are drawn over the tiled ones).
#       Sets win_w / win_h (window size) and content (all panes' text).
#   hint_canvas_size
#       Sets canvas_w / canvas_h: the window size clipped to the popup, keeping
#       the last row for the prompt.
#   hint_save_capture <work_dir> / hint_load_capture <work_dir>
#       Persist / restore what hint_capture_window set (geom_file, win_w,
#       win_h, content), so the launcher can capture before opening the popup
#       and the popup only draws. Capture BEFORE the popup: in recent tmux a
#       popup is a floating pane, and opening one over a zoomed pane briefly
#       unzooms the window, so the panes under it get resized twice. TUIs
#       redraw on that (pi rewrites its whole screen), and a capture taken from
#       inside the popup catches them mid-redraw (old scrollback on screen).
#   HINT_DRAW_AWK
#       awk source defining the HINT / RESET styles, at(y, x, s) and
#       draw_window(): draws every pane at
#       its real position (cursor addressing, so wide characters can't shift
#       columns) followed by the pane borders and junctions, then the
#       floating panes in a box on top. draw_window() calls
#       annotate(line, pane_id, row), which the caller's awk program defines.
#       Needs -v W=<canvas_w> -v H=<canvas_h> -v GEOM=<geometry file>.

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Prefer gawk (UTF-8 aware: lengths and substr count characters, not bytes)
AWK=$(command -v gawk || command -v awk)
# Character-aware string ops need a UTF-8 locale
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) ;;
    *) export LC_ALL=C.UTF-8 ;;
esac

ALPHABET="asdfghjklqwertyuiopzxcvbnm"
ALPHA_LEN=${#ALPHABET}

# Capture what a pane is showing. In copy mode that is the scrolled view, not
# the bottom of the history.
hint_capture_pane() {
    local pid="$1" in_mode="$2" scroll_pos="$3" height="$4"
    if [ "$in_mode" = "1" ] && [ "$scroll_pos" -gt 0 ] 2>/dev/null; then
        tmux capture-pane -p -t "$pid" -S "$(( -scroll_pos ))" -E "$(( -scroll_pos + height - 1 ))" 2>/dev/null
    else
        tmux capture-pane -p -t "$pid" 2>/dev/null
    fi
}

hint_capture_window() {
    local caller="$1" c_mode="$2" c_scroll="$3" c_height="$4" zoomed="$5" dir="$6"
    local window_id pid left top width height mode scroll floating pane_content pane_file floats=""
    window_id=$(tmux display-message -p -t "$caller" '#{window_id}')
    read -r win_w win_h < <(tmux display-message -p -t "$caller" '#{window_width} #{window_height}')
    geom_file="$dir/geometry"
    : > "$geom_file"
    content=""
    while IFS=$'\t' read -r pid left top width height mode scroll floating; do
        # The picker's own popup is a pane in recent tmux: skip it
        [ "$pid" = "${TMUX_PANE:-}" ] && continue
        if [ "$zoomed" = "1" ] && [ "$floating" != "1" ]; then
            # Only the zoomed pane is visible (and floating panes made to stay
            # above it); it fills the whole window
            [ "$pid" = "$caller" ] || continue
            left=0 top=0 width=$win_w height=$win_h
        fi
        # The caller's state comes from the key binding, captured before the
        # popup opened
        [ "$pid" = "$caller" ] && mode=$c_mode scroll=$c_scroll height=$c_height
        pane_content=$(hint_capture_pane "$pid" "$mode" "${scroll:-0}" "$height")
        pane_file="$dir/pane${pid#%}"
        printf '%s\n' "$pane_content" > "$pane_file"
        if [ "$floating" = "1" ]; then
            floats+="$left	$top	$width	$height	$pane_file	$pid	1"$'\n'
        else
            printf '%s\t%s\t%s\t%s\t%s\t%s\t0\n' "$left" "$top" "$width" "$height" "$pane_file" "$pid" >> "$geom_file"
        fi
        if [ -n "$pane_content" ]; then
            [ -n "$content" ] && content+=$'\n'
            content+="$pane_content"
        fi
    done < <(tmux list-panes -t "$window_id" -F '#{pane_id}	#{pane_left}	#{pane_top}	#{pane_width}	#{pane_height}	#{pane_in_mode}	#{?scroll_position,#{scroll_position},0}	#{pane_floating_flag}')
    # (scroll_position is empty outside copy mode; read would merge the empty
    # tab-separated field, hence the 0 default above)
    printf '%s' "$floats" >> "$geom_file"
}

hint_save_capture() {
    printf '%s %s\n' "$win_w" "$win_h" > "$1/size"
    printf '%s' "$content" > "$1/content"
}

hint_load_capture() {
    geom_file="$1/geometry"
    read -r win_w win_h < "$1/size"
    content=$(cat "$1/content")
}

hint_canvas_size() {
    local term_rows term_cols
    read -r term_rows term_cols < <(stty size < /dev/tty 2>/dev/null)
    canvas_w=$win_w; canvas_h=$win_h
    [ -n "$term_cols" ] && [ "$term_cols" -lt "$canvas_w" ] && canvas_w=$term_cols
    [ -n "$term_rows" ] && [ "$term_rows" -le "$canvas_h" ] && canvas_h=$((term_rows - 1))
}

HINT_DRAW_AWK='
# Hint style, shared by both pickers: black (16) on bright yellow (226) from
# the fixed 256-colour cube, so terminal themes cannot remap it into a dull
# yellow or a grey "black". Contrast ratio ~19.6:1.
BEGIN { HINT = "\033[1;38;5;16;48;5;226m"; RESET = "\033[0m" }
function at(y, x, s) { if (y >= 0 && x >= 0 && y < H && x < W) printf "\033[%d;%dH%s", y + 1, x + 1, s }
function rep(s, n,    r) { r = ""; while (n-- > 0) r = r s; return r }
# One pane: its captured rows at its position, each passed through annotate()
function draw_pane(left, top, pw, ph, file, pid,    i, line) {
    for (i = 0; i < ph; i++) {
        if ((getline line < file) <= 0) break
        # Blank rows too: they can carry a hint (line jump)
        at(top + i, left, annotate(line, pid, i))
    }
    close(file)
}
function draw_window(    g, f, left, top, pw, ph, i, k, yx, y, x, up, dn, lt, rt, vb, hb, nf, fl) {
    printf "\033[H\033[2J\033[?7l"   # clear; no autowrap, so clipped lines cannot spill
    while ((getline g < GEOM) > 0) {
        split(g, f, "\t")
        if (f[7] == "1") { fl[++nf] = g; continue }   # floating: drawn last
        left = f[1] + 0; top = f[2] + 0; pw = f[3] + 0; ph = f[4] + 0
        draw_pane(left, top, pw, ph, f[5], f[6])
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
    # Floating panes on top: a box, the area under it blanked, then the text
    for (k = 1; k <= nf; k++) {
        split(fl[k], f, "\t")
        left = f[1] + 0; top = f[2] + 0; pw = f[3] + 0; ph = f[4] + 0
        at(top - 1, left - 1, "┌"); at(top - 1, left, rep("─", pw)); at(top - 1, left + pw, "┐")
        for (i = 0; i < ph; i++) { at(top + i, left - 1, "│"); at(top + i, left, rep(" ", pw)); at(top + i, left + pw, "│") }
        at(top + ph, left - 1, "└"); at(top + ph, left, rep("─", pw)); at(top + ph, left + pw, "┘")
        draw_pane(left, top, pw, ph, f[5], f[6])
    }
    printf "\033[%d;1H\033[?7h", H + 1
}
'
