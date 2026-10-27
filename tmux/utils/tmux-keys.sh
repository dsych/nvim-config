#!/usr/bin/env bash
# tmux-keys.sh - searchable list of every tmux key binding (all tables).
# $1 = client name of the caller (popup steals context, so it is passed in).
#
# Rows: TABLE  KEY  DESCRIPTION  COMMAND. Typing searches all four, so a
# binding can be found by what it does, not only by its key or command.
#
# The description is the binding's note (bind -N): tmux's own defaults have
# one, and tmux.conf gives one to every binding it makes. Bindings without a
# note (tmux's copy-mode and mouse defaults) are described by the table in
# descriptions() below.
#
# Commands are listed without what tmux-copy-cursorline.sh appends to almost
# every copy-mode binding: otherwise searching "pane", "mark" or "url" would
# match all of them. The preview shows the full command.
#
# Enter on a prefix/root binding fires it in the caller's client once the
# popup has closed (send-keys -K replays the key through the binding tables).
#
#   tmux-keys.sh --rows   print the rows (tab-separated) instead (tests)
#
# Needs tmux 3.7+ (list-keys -F).

set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

ROWS_ONLY=0
[ "${1:-}" = "--rows" ] && { ROWS_ONLY=1; shift; }
CLIENT="${1:-}"
TAB=$'\t'

# Descriptions of bindings that have no note, columns split by 2+ spaces:
#   cmd  <command>  <description>
#       a binding whose first copy-mode command is send-keys -X <command>
#   key  <table>  <key>  <command start>  <description>
#       one of tmux's default bindings (table "copy" = both copy-mode tables).
#       Only used while the command still starts with <command start>, so a
#       key bound to something else isn't described as tmux's default.
descriptions() {
    cat <<'EOF'
# Copy-mode commands (the COPY MODE list in tmux(1))
cmd  append-selection                  Append the selection to the paste buffer
cmd  append-selection-and-cancel       Append the selection to the paste buffer and exit copy mode
cmd  back-to-indentation               Cursor to the first non-blank character of the line
cmd  begin-selection                   Start a selection
cmd  bottom-line                       Cursor to the bottom line of the screen
cmd  cancel                            Exit copy mode
cmd  clear-selection                   Clear the selection
cmd  copy-end-of-line                  Copy to the end of the line
cmd  copy-end-of-line-and-cancel       Copy to the end of the line and exit copy mode
cmd  copy-line                         Copy the whole line
cmd  copy-line-and-cancel              Copy the whole line and exit copy mode
cmd  copy-pipe                         Copy the selection
cmd  copy-pipe-and-cancel              Copy the selection and exit copy mode
cmd  copy-pipe-end-of-line             Copy to the end of the line
cmd  copy-pipe-end-of-line-and-cancel  Copy to the end of the line and exit copy mode
cmd  copy-pipe-line                    Copy the whole line
cmd  copy-pipe-line-and-cancel         Copy the whole line and exit copy mode
cmd  copy-pipe-no-clear                Copy the selection and keep it selected
cmd  copy-selection                    Copy the selection
cmd  copy-selection-and-cancel         Copy the selection and exit copy mode
cmd  copy-selection-no-clear           Copy the selection and keep it selected
cmd  cursor-centre-horizontal          Cursor to the middle column of the pane
cmd  cursor-centre-vertical            Cursor to the middle row of the pane
cmd  cursor-down                       Cursor down
cmd  cursor-down-and-cancel            Cursor down, exit copy mode at the bottom
cmd  cursor-left                       Cursor left
cmd  cursor-right                      Cursor right
cmd  cursor-up                         Cursor up
cmd  end-of-line                       Cursor to the end of the line
cmd  goto-line                         Go to a line number
cmd  halfpage-down                     Scroll down half a page
cmd  halfpage-down-and-cancel          Scroll down half a page, exit copy mode at the bottom
cmd  halfpage-up                       Scroll up half a page
cmd  history-bottom                    Go to the bottom of the history
cmd  history-top                       Go to the top of the history
cmd  jump-again                        Repeat the last character jump (f F t T)
cmd  jump-backward                     Jump back to a character
cmd  jump-forward                      Jump forward to a character
cmd  jump-reverse                      Repeat the last character jump in the other direction
cmd  jump-to-backward                  Jump back to just after a character
cmd  jump-to-forward                   Jump forward to just before a character
cmd  jump-to-mark                      Jump to the mark (swaps the cursor and the mark)
cmd  line-numbers-off                  Hide line numbers
cmd  line-numbers-on                   Show line numbers
cmd  line-numbers-toggle               Show or hide line numbers
cmd  middle-line                       Cursor to the middle line of the screen
cmd  next-matching-bracket             Cursor to the matching bracket (forward)
cmd  next-paragraph                    Next paragraph
cmd  next-prompt                       Next shell prompt
cmd  next-space                        Next WORD (whitespace-separated word)
cmd  next-space-end                    End of the WORD (whitespace-separated word)
cmd  next-word                         Next word
cmd  next-word-end                     End of the word
cmd  other-end                         Cursor to the other end of the selection
cmd  page-down                         Scroll down a page
cmd  page-down-and-cancel              Scroll down a page, exit copy mode at the bottom
cmd  page-up                           Scroll up a page
cmd  pipe                              Pipe the selection to a command
cmd  pipe-and-cancel                   Pipe the selection to a command and exit copy mode
cmd  pipe-no-clear                     Pipe the selection to a command and keep it selected
cmd  previous-matching-bracket         Cursor to the matching bracket (backward)
cmd  previous-paragraph                Previous paragraph
cmd  previous-prompt                   Previous shell prompt
cmd  previous-space                    Previous WORD (whitespace-separated word)
cmd  previous-word                     Previous word
cmd  recentre-top-bottom               Scroll the cursor line to the middle, top, bottom in turn
cmd  rectangle-off                     Rectangle (block) selection off
cmd  rectangle-on                      Rectangle (block) selection on
cmd  rectangle-toggle                  Rectangle (block) selection on or off
cmd  refresh-now                       Refresh the content from the pane
cmd  refresh-off                       Stop showing new output in copy mode
cmd  refresh-on                        Keep showing new output in copy mode
cmd  refresh-toggle                    Start or stop showing new output in copy mode
cmd  scroll-bottom                     Scroll the cursor line to the bottom
cmd  scroll-down                       Scroll down a line
cmd  scroll-down-and-cancel            Scroll down a line, exit copy mode at the bottom
cmd  scroll-exit-off                   Stay in copy mode when scrolled to the bottom
cmd  scroll-exit-on                    Exit copy mode when scrolled to the bottom
cmd  scroll-exit-toggle                Exit copy mode when scrolled to the bottom: on or off
cmd  scroll-middle                     Scroll the cursor line to the middle
cmd  scroll-to-mouse                   Scroll to the mouse (scrollbar drag)
cmd  scroll-top                        Scroll the cursor line to the top
cmd  scroll-up                         Scroll up a line
cmd  search-again                      Repeat the last search
cmd  search-backward                   Search up (regex)
cmd  search-backward-incremental       Search up as you type
cmd  search-backward-text              Search up for plain text
cmd  search-forward                    Search down (regex)
cmd  search-forward-incremental        Search down as you type
cmd  search-forward-text               Search down for plain text
cmd  search-reverse                    Repeat the last search in the other direction
cmd  select-line                       Select the whole line
cmd  select-word                       Select the word under the cursor
cmd  selection-mode                    Change the selection mode
cmd  set-mark                          Set the mark on the cursor line
cmd  start-of-line                     Cursor to the start of the line
cmd  stop-selection                    Stop extending the selection, keep it
cmd  toggle-position                   Show or hide the position indicator (top right)
cmd  top-line                          Cursor to the top line of the screen

# tmux's default mouse bindings and a few copy-mode keys
key  root  MouseDown1Pane             select-pane -t =    Click a pane: select it (apps using the mouse get the click)
key  root  MouseDown1Border           select-pane -t =    Click a pane border: select the pane
key  root  MouseDown1Status           switch-client -t =  Click a window in the status line: switch to it
key  root  C-MouseDown1Status         swap-window         Ctrl+click a window in the status line: swap it with the current one
key  root  WheelUpStatus              previous-window     Mouse wheel up on the status line: previous window
key  root  WheelDownStatus            next-window         Mouse wheel down on the status line: next window
key  root  WheelUpPane                if-shell            Mouse wheel up in a pane: scroll back (enters copy mode)
key  root  MouseDrag1Pane             if-shell            Drag in a pane: select text (enters copy mode)
key  root  MouseDrag1Border           resize-pane -M      Drag a pane border: resize the pane
key  root  DoubleClick1Pane           select-pane -t =    Double-click a word: copy it
key  root  TripleClick1Pane           select-pane -t =    Triple-click a line: copy it
key  root  MouseDown2Pane             select-pane -t =    Middle-click a pane: paste (apps using the mouse get the click)
key  root  MouseDown3Pane             if-shell            Right-click a pane: pane menu (apps using the mouse get the click)
key  root  M-MouseDown3Pane           display-menu        Alt+right-click a pane: pane menu
key  root  MouseDown3Status           display-menu        Right-click a window in the status line: window menu
key  root  M-MouseDown3Status         display-menu        Alt+right-click a window in the status line: window menu
key  root  MouseDown3StatusLeft       run-shell           Right-click the session name: session menu
key  root  M-MouseDown3StatusLeft     run-shell           Alt+right-click the session name: session menu
key  root  MouseDown3Empty            display-menu        Right-click empty space: new pane or window menu
key  root  M-MouseDown3Empty          display-menu        Alt+right-click empty space: new pane or window menu
key  root  MouseDown1ScrollbarUp      if-shell            Click the scrollbar above the slider: page up
key  root  MouseDown1ScrollbarDown    if-shell            Click the scrollbar below the slider: page down
key  root  MouseDrag1ScrollbarSlider  if-shell            Drag the scrollbar slider: scroll the history
key  root  MouseDown1Control7         if-shell            Click the float button on a pane border: float or tile the pane
key  root  MouseDown1Control8         resize-pane -Z      Click the zoom button on a pane border: zoom or unzoom the pane
key  root  MouseDown1Control9         display-menu        Click the close button on a pane border: kill the pane (asks first)
key  root  M-MouseDrag1Pane           move-pane -M        Alt+drag a pane: move it (floating panes)
key  root  M-MouseDrag1Border         move-pane -M        Alt+drag a pane border: move the pane (floating panes)
key  root  C-MouseDrag1Pane           new-pane -M         Ctrl+drag in a pane: draw a new floating pane
key  root  C-MouseDrag1Empty          new-pane -M         Ctrl+drag on empty space: draw a new floating pane
key  copy  MouseDown1Pane             select-pane         Click: select the pane
key  copy  MouseDrag1Pane             select-pane         Drag: select text
key  copy  MouseDragEnd1Pane          send-keys -X copy-pipe-and-cancel  Release the drag: copy the selection and exit copy mode
key  copy  WheelUpPane                select-pane         Mouse wheel up: scroll up
key  copy  WheelDownPane              select-pane         Mouse wheel down: scroll down
key  copy  DoubleClick1Pane           select-pane         Double-click a word: copy it and exit copy mode
key  copy  TripleClick1Pane           select-pane         Triple-click a line: copy it and exit copy mode
key  copy-mode-vi  #                  send-keys -FX search-backward  Search up for the word under the cursor
key  copy-mode-vi  *                  send-keys -FX search-forward   Search down for the word under the cursor
EOF
}

# The bindings, one per line: table, key, prefix, repeat, note, command
if ! bindings=$(tmux list-keys -F "#{key_table}${TAB}#{key_string}${TAB}#{key_prefix}${TAB}#{key_repeat}${TAB}#{key_note}${TAB}#{key_command}" 2>&1); then
    msg="prefix ? needs tmux 3.7 or newer (list-keys -F): $bindings"
    [ "$ROWS_ONLY" = 1 ] && { echo "$msg" >&2; exit 1; }
    tmux display-message ${CLIENT:+-c "$CLIENT"} "$msg"
    exit 1
fi
copy_table=copy-mode
[ "$(tmux show-options -gwv mode-keys 2>/dev/null)" = vi ] && copy_table=copy-mode-vi
cols=$(tput cols 2>/dev/null) || cols=120

# Row fields: 1 table, 2 key, 3 prefix, 4 title (preview), 5 description,
# 6 command, then what is shown: 7 table, 8 key, 9 description, 10 command
# (padded; fzf --tabstop=1 shows each tab as one space). C locale; width()
# counts characters either way: macOS's awk may count UTF-8 characters
# regardless, gawk/mawk count bytes there.
rows=$(printf '%s\n' "$bindings" | LC_ALL=C awk -v copy_table="$copy_table" -v cols="$cols" '
    function width(s,    t) {
        if (chars) return length(s)
        t = s; gsub(continuation, "", t); return length(t)
    }
    function pad(s, w,    n) { n = w - width(s); return n > 0 ? s sprintf("%" n "s", "") : s }

    # The command without what tmux-copy-cursorline.sh appended (wrapped[]):
    # " \; <added>" after a plain command, " ; <added>" inside { ... }
    function unwrap(cmd,    i, j, at) {
        at = 0
        for (j in wrapped)
            if ((i = index(cmd, wrapped[j])) > 0 && (at == 0 || i < at)) at = i
        if (at > 4 && substr(cmd, at - 4, 4) == " \\; ") return substr(cmd, 1, at - 5)
        if (at > 3 && substr(cmd, at - 3, 3) == " ; ") return substr(cmd, 1, at - 4) " }"
        return cmd
    }

    # First copy-mode command the binding runs: send-keys -X [-N 5] <name>
    function copy_command(cmd,    m) {
        if (!match(cmd, /send-keys( -[A-Za-z]+| [0-9]+)* [a-z][a-z-]*/)) return ""
        m = substr(cmd, RSTART, RLENGTH)
        if (m !~ / -[A-Za-z]*X/) return ""
        sub(/.* /, "", m)
        return m
    }

    function describe(table, key, cmd,    k, name) {
        k = table SUBSEP key
        if (!(k in keydesc) && table ~ /^copy-mode/) k = "copy" SUBSEP key
        if ((k in keydesc) && index(cmd, keystart[k]) == 1) return keydesc[k]
        if (cmd ~ /\(repeat\)/) return "Repeat count for the next command"
        if ((name = copy_command(cmd)) == "") return ""
        if (name in cmddesc) return cmddesc[name]
        gsub(/-/, " ", name)   # a copy-mode command newer than the table
        return toupper(substr(name, 1, 1)) substr(name, 2)
    }

    # prefix, root, the copy-mode table in use (mode-keys), others, the other one
    function rank(t) {
        return t == "prefix" ? 0 : t == "root" ? 1 : t == copy_table ? 2 : t ~ /^copy-mode/ ? 4 : 3
    }

    BEGIN {
        FS = "\t"; OFS = "\t"
        chars = length("\303\251") == 1   # this awk counts "é" as one character
        # else skip UTF-8 continuation bytes; a string, so that an awk reading
        # UTF-8 never compiles it (a byte range is invalid there)
        continuation = "[\200-\277]"
        wrapped[1] = "if-shell -F \"#{||:#{==:#{pane_mode},copy-mode},#{==:#{pane_mode},view-mode}}\" \"send-keys -X set-mark\""
        wrapped[2] = "if-shell -F \"#{&&:#{!:#{@link-peek-float}},#{!=:#{copy_cursor_hyperlink},#{@link-peek-url}}}\""
        TABLE = "\033[34m"; KEY = "\033[1m"; CMD = "\033[90m"; OFF = "\033[0m"
    }

    FNR == NR {   # the description table
        if ($0 ~ /^(#|$)/) next
        n = split($0, f, /  +/)
        if (f[1] == "cmd" && n >= 3) cmddesc[f[2]] = f[3]
        if (f[1] == "key" && n >= 5) { keystart[f[2], f[3]] = f[4]; keydesc[f[2], f[3]] = f[5] }
        next
    }

    NF >= 6 {
        cmd = $6
        for (i = 7; i <= NF; i++) cmd = cmd "\t" $i
        shown = unwrap(cmd)
        desc = $5 != "" ? $5 : describe($1, $2, shown)
        name = $1 == "prefix" ? $3 " " $2 : $2
        N++; R[N] = rank($1); T[N] = $1; K[N] = $2; P[N] = $3; NM[N] = name
        RP[N] = $4; D[N] = desc; C[N] = cmd; S[N] = shown
        if (width($1) > tw) tw = width($1)
        if (width(name) > kw) kw = width(name)
        if (width(desc) > dw) dw = width(desc)
    }

    END {
        if (kw > (cols < 140 ? 16 : 26)) kw = cols < 140 ? 16 : 26   # long mouse keys overflow
        # leave the command some room on narrow screens
        max = int((cols - tw - kw - 10) * 0.6); if (max < 30) max = 30
        if (dw > max) dw = max
        for (r = 0; r <= 4; r++)
            for (i = 1; i <= N; i++) {
                if (R[i] != r) continue
                title = T[i] "  " NM[i] (RP[i] == "1" ? "  (repeats: press the key again without the prefix)" : "")
                print T[i], K[i], P[i], title, D[i], C[i], TABLE pad(T[i], tw) OFF " ",
                    KEY pad(NM[i], kw) OFF " ", pad(D[i], dw) " ", CMD S[i] OFF
            }
    }
' <(descriptions) -)

if [ "$ROWS_ONLY" = 1 ]; then
    printf '%s\n' "$rows"
    exit 0
fi

# Searched: key, description and command, not the table ("copy" would match
# every copy-mode binding). Ties (same match quality) go to the match nearest
# the start, i.e. to the description over the command, then to the row order.
# No horizontal scrolling to a match: the key and description stay in view.
selected=$(printf '%s\n' "$rows" | fzf \
    --ansi --reverse --exact --no-info \
    --tiebreak=begin,index --no-hscroll \
    --delimiter="$TAB" --with-nth=7.. --nth=2.. --tabstop=1 \
    --header="Key bindings: type what it does, a key or a command   Enter: run it   Esc: close" \
    --preview='printf "%s\n%s\n\n%s\n" {4} {5} {6}' \
    --preview-window='down:7:wrap' 2>/dev/null)

[ -z "$selected" ] && exit 0

IFS="$TAB" read -r table key prefix _ <<<"$selected"

case "$table" in
    prefix) keys=("$prefix" "$key") ;;
    root)   keys=("$key") ;;
    *)      tmux display-message "Key table '$table' only applies inside that mode; not run."; exit 0 ;;
esac
case "$key" in
    *Mouse*|*Click*|*Wheel*) tmux display-message "Mouse binding; not run."; exit 0 ;;
esac

# Replay after the popup closes (keys sent now would go to the popup itself).
# Hand the delayed send-keys to the tmux server: a background job started from
# inside the popup is killed when the popup exits.
printf -v quoted ' %q' "${keys[@]}"
quoted=${quoted//#/##}   # run-shell expands #{...} formats
tmux run-shell -b "sleep 0.25; tmux send-keys -K ${CLIENT:+-c $(printf %q "$CLIENT")}$quoted"
