#!/usr/bin/env bash
# tmux-link-peek.sh - show the URL behind the hyperlink under the copy-mode
# cursor in a small floating pane in the window's bottom-right corner.
#
# Programs can print OSC 8 hyperlinks, where the visible text ("click here")
# hides the URL. tmux keeps the URL (#{copy_cursor_hyperlink}) but can't show it
# in the pane, so this puts it in a real pane: prefix+q / prefix+e pick it up,
# and prefix+j can jump into it to select it in copy mode.
#
# Usage: tmux-link-peek.sh update <pane_id>   show/refresh/hide for that pane
#        tmux-link-peek.sh hide <pane_id>     remove the peek pane of its window
#        tmux-link-peek.sh close <pane_id>    close it from inside (q / Esc)
#        tmux-link-peek.sh view <url>         what the peek pane runs
#
# The peek pane is read-only: `view` prints the URL and swallows all input with
# echo off, closing on q or a bare Esc. After prefix+j into it (copy mode), the
# copy-mode q / Esc bindings in tmux.conf call `close` instead.
#
# Called from the copy-mode movement bindings (tmux-copy-cursorline.sh wraps
# them), the pane-mode-changed hook and tmux-jump.sh. The bindings only call it
# when the link under the cursor changed (window option @link-peek-url), so
# moving around plain text costs nothing. set -g @link-peek off to disable.
#
# State: window option @link-peek-pane = the peek pane's id; the peek pane has
# pane option @link-peek-float=1 (the hooks ignore it, so jumping into it to
# copy the URL doesn't close it).

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

action="${1:-update}"
pane="${2:-}"
[ -n "$pane" ] || exit 0

# Closing by the user: forget the state (so the same link shows again when the
# cursor comes back to it) and remove the pane. Only if it still is the peek
# pane; a stale call must not clear a newer one.
close_peek() {
    local p="$1" w
    [ "$(tmux show-options -pqv -t "$p" @link-peek-float 2>/dev/null)" = "1" ] || return 0
    w=$(tmux display-message -p -t "$p" '#{window_id}')
    [ "$(tmux show-options -wqv -t "$w" @link-peek-pane)" = "$p" ] &&
        tmux set-option -wu -t "$w" @link-peek-pane \; set-option -wu -t "$w" @link-peek-url
    tmux kill-pane -t "$p"
}

case "$action" in
    view)
        # Runs inside the peek pane: show the URL, ignore input, exit on q / Esc
        printf '%s' "$pane"
        stty -echo -icanon min 1 time 0 2>/dev/null
        esc=$(printf '\033')
        while :; do
            k=$(dd bs=1 count=1 2>/dev/null) || exit 0
            [ "$k" = "q" ] && break
            if [ "$k" = "$esc" ]; then
                # A bare Esc, or the start of a key sequence (arrows, ...)?
                stty min 0 time 1 2>/dev/null
                rest=$(dd bs=16 count=1 2>/dev/null)
                stty min 1 time 0 2>/dev/null
                [ -z "$rest" ] && break
            fi
        done
        close_peek "$TMUX_PANE"
        exit 0 ;;
    close)
        close_peek "$pane"
        exit 0 ;;
esac

# Serialize: a burst of cursor moves can start several updates at once
if command -v flock >/dev/null 2>&1; then
    exec 9>"${TMPDIR:-/tmp}/tmux-link-peek-$(id -u).lock"
    flock 9
fi

window=$(tmux display-message -p -t "$pane" '#{window_id}' 2>/dev/null) || exit 0
[ -n "$window" ] || exit 0
# Never act on behalf of the peek pane itself
[ "$(tmux show-options -pqv -t "$pane" @link-peek-float)" = "1" ] && exit 0

peek=$(tmux show-options -wqv -t "$window" @link-peek-pane)
# Forget a peek pane that no longer exists (killed by hand, layout reset, ...)
if [ -n "$peek" ] && [ "$(tmux show-options -pqv -t "$peek" @link-peek-float 2>/dev/null)" != "1" ]; then
    peek=""
    tmux set-option -wu -t "$window" @link-peek-pane
fi

hide() {
    [ -n "$peek" ] && tmux kill-pane -t "$peek" 2>/dev/null
    tmux set-option -wu -t "$window" @link-peek-pane \; set-option -wu -t "$window" @link-peek-url
}

url=""
if [ "$action" = "update" ] && [ "$(tmux show-options -gqv @link-peek)" != "off" ]; then
    url=$(tmux display-message -p -t "$pane" \
        '#{?#{||:#{==:#{pane_mode},copy-mode},#{==:#{pane_mode},view-mode}},#{copy_cursor_hyperlink},}')
fi
if [ -z "$url" ]; then
    hide
    exit 0
fi
tmux set-option -w -t "$window" @link-peek-url "$url"

# Box size: the URL on one line if it fits, else wrapped at the window width.
# -x/-y/-X/-Y of floating panes include the border.
read -r win_w win_h < <(tmux display-message -p -t "$pane" '#{window_width} #{window_height}')
len=${#url}
inner_w=$len
max_w=$(( win_w - 2 ))
[ "$inner_w" -gt "$max_w" ] && inner_w=$max_w
[ "$inner_w" -lt 1 ] && exit 0
inner_h=$(( (len + inner_w - 1) / inner_w ))
box_w=$(( inner_w + 2 )); box_h=$(( inner_h + 2 ))
x=$(( win_w - box_w )); y=$(( win_h - box_h ))
[ "$y" -lt 0 ] && y=0

# The URL is passed as an argument, never parsed by a shell
show=("$SELF" view "$url")

if [ -n "$peek" ]; then
    tmux respawn-pane -k -t "$peek" "${show[@]}" \; \
        resize-pane -t "$peek" -x "$box_w" -y "$box_h" \; \
        move-pane -t "$peek" -X "$x" -Y "$y"
else
    # -d: don't take focus (no focus hooks fire); -A: stay visible over a
    # zoomed pane
    style=$(tmux show-options -gqv @link-peek-border-style)
    peek=$(tmux new-pane -d -A -t "$pane" -x "$box_w" -y "$box_h" -X "$x" -Y "$y" \
        ${style:+-R "$style"} -P -F '#{pane_id}' "${show[@]}") || exit 0
    tmux set-option -p -t "$peek" @link-peek-float 1 \; \
        set-option -w -t "$window" @link-peek-pane "$peek"
fi
exit 0
