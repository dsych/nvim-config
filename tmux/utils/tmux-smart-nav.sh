#!/usr/bin/env bash
# tmux-smart-nav.sh - Cursor-position-aware pane navigation
# Selects the pane in the given direction containing the cursor's absolute
# column (U/D) or row (L/R). No wrap-around. Prefer a local neighbour even
# when leaving an SSH pane.
# At an SSH edge forward the original key; zoomed SSH always forwards without
# unzooming, so the remote tmux can navigate its own layout.
# Usage: tmux-smart-nav.sh [U|D|L|R] [original-key] [origin-pane]

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

direction=${1:?Usage: tmux-smart-nav.sh [U|D|L|R] [key] [pane]}
case "$direction" in
    U) default_key=M-K ;; D) default_key=M-J ;;
    L) default_key=M-H ;; R) default_key=M-L ;;
    *) exit 1 ;;
esac
key=${2:-$default_key}
pane=${3:-${TMUX_PANE:-}}
# Pin every query and action to the pane that received the key, not the best
# client (which can change while a run-shell command is queued).
IFS='|' read -r cur_id zoomed current_command < <(
    tmux display-message -p -t "$pane" '#{pane_id}|#{window_zoomed_flag}|#{pane_current_command}')
[ -n "$cur_id" ] || exit 1
remote=0; [ "$current_command" = ssh ] && remote=1
if [ "$remote" = 1 ] && [ "$zoomed" = 1 ]; then
    tmux send-keys -t "$cur_id" -- "$key"
    exit $?
fi
# A zoomed local pane keeps the previous behaviour: restore local geometry.
[ "$zoomed" = 1 ] && tmux resize-pane -Z -t "$cur_id"

# Numeric geometry from tmux; read it as data, never eval it.
IFS='|' read -r cur_left cur_top cur_w cur_h cur_x cur_y in_mode copy_x copy_y < <(
    tmux display-message -p -t "$cur_id" \
    '#{pane_left}|#{pane_top}|#{pane_width}|#{pane_height}|#{cursor_x}|#{cursor_y}|#{pane_in_mode}|#{copy_cursor_x}|#{copy_cursor_y}')

# In copy mode, use the copy cursor position instead
if [ "$in_mode" = "1" ] && [ -n "$copy_x" ]; then
    cur_x=$copy_x
    cur_y=$copy_y
fi

# Absolute cursor position on the window grid
abs_x=$((cur_left + cur_x))
abs_y=$((cur_top + cur_y))

# Find the closest pane in the target direction that contains the cursor coordinate
best_id=""
best_dist=999999

while read -r id left top w h; do
    [ "$id" = "$cur_id" ] && continue
    right=$((left + w))
    bottom=$((top + h))

    case "$direction" in
        D)  # Pane must be below, and cursor x must fall within its width
            [ "$top" -le "$((cur_top + cur_h))" ] && continue
            { [ "$abs_x" -lt "$left" ] || [ "$abs_x" -ge "$right" ]; } && continue
            dist=$((top - cur_top - cur_h))
            ;;
        U)  # Pane must be above
            [ "$bottom" -ge "$cur_top" ] && continue
            { [ "$abs_x" -lt "$left" ] || [ "$abs_x" -ge "$right" ]; } && continue
            dist=$((cur_top - bottom))
            ;;
        L)  # Pane must be to the left, and cursor y must fall within its height
            [ "$right" -ge "$cur_left" ] && continue
            { [ "$abs_y" -lt "$top" ] || [ "$abs_y" -ge "$bottom" ]; } && continue
            dist=$((cur_left - right))
            ;;
        R)  # Pane must be to the right
            [ "$left" -le "$((cur_left + cur_w))" ] && continue
            { [ "$abs_y" -lt "$top" ] || [ "$abs_y" -ge "$bottom" ]; } && continue
            dist=$((left - cur_left - cur_w))
            ;;
    esac

    if [ "$dist" -lt "$best_dist" ]; then
        best_dist=$dist
        best_id=$id
    fi
done < <(tmux list-panes -t "$cur_id" -F '#{pane_id} #{pane_left} #{pane_top} #{pane_width} #{pane_height}')

if [ -n "$best_id" ]; then
    tmux select-pane -t "$best_id"
elif [ "$remote" = 1 ]; then
    tmux send-keys -t "$cur_id" -- "$key"
fi
exit 0
