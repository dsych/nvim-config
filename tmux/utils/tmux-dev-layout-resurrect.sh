#!/usr/bin/env bash
# tmux-dev-layout-resurrect.sh - persist dev-layout pane tags across tmux-resurrect
#
# tmux-resurrect does not save pane user options, so the @dev-layout-bottom tag
# set by tmux-dev-layout.sh is lost on restore and the pane-focus-in auto-resize
# hook stops firing. This script stores the tags inside the resurrect snapshot
# and re-applies them after a restore.
#
# Wired up in tmux.conf:
#   set -g @resurrect-hook-post-save-layout '~/.config/tmux/utils/tmux-dev-layout-resurrect.sh save'
#   set -g @resurrect-hook-post-restore-all '~/.config/tmux/utils/tmux-dev-layout-resurrect.sh restore'
#
# Snapshot line format (tab separated; prefix must not collide with resurrect's
# own "pane"/"window"/"state"/"grouped_session" line types):
#   dev_layout_bottom<TAB>session<TAB>window_index<TAB>pane_index

set -uo pipefail

LINE_TYPE="dev_layout_bottom"
OPTION="@dev-layout-bottom"

resurrect_dir() {
    local dir
    dir=$(tmux show-option -gqv @resurrect-dir)
    if [ -z "$dir" ]; then
        if [ -d "$HOME/.tmux/resurrect" ]; then
            dir="$HOME/.tmux/resurrect"
        else
            dir="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
        fi
    fi
    # same expansion rules as tmux-resurrect's helpers.sh
    echo "$dir" | sed "s,\$HOME,$HOME,g; s,\$HOSTNAME,$(hostname),g; s,\~,$HOME,g"
}

save() {
    # $1 = snapshot file being written (passed by post-save-layout hook)
    local file="${1:-}"
    [ -n "$file" ] && [ -f "$file" ] || exit 0
    tmux list-panes -a -F "#{${OPTION}}	#{session_name}	#{window_index}	#{pane_index}" |
        while IFS=$'\t' read -r tag session window pane; do
            [ "$tag" = "1" ] && printf '%s\t%s\t%s\t%s\n' "$LINE_TYPE" "$session" "$window" "$pane"
        done >> "$file"
}

restore() {
    local file
    file="$(resurrect_dir)/last"
    [ -f "$file" ] || exit 0
    while IFS=$'\t' read -r type session window pane; do
        [ "$type" = "$LINE_TYPE" ] || continue
        tmux set-option -p -t "${session}:${window}.${pane}" "$OPTION" 1 2>/dev/null || true
    done < "$file"
}

case "${1:-}" in
    save) shift; save "$@" ;;
    restore) restore ;;
    *) echo "usage: $0 save <resurrect-file> | restore" >&2; exit 1 ;;
esac
