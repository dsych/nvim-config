#!/usr/bin/env bash
# tmux-smart-nav.sh - Cursor-position-aware pane navigation
# Selects the pane in the given direction that contains the cursor's
# absolute column (for U/D) or row (for L/R). No wrap-around.
# Usage: tmux-smart-nav.sh [U|D|L|R]

# Ensure common tool paths are available (Homebrew on macOS, etc.)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

direction=${1:?Usage: tmux-smart-nav.sh [U|D|L|R]}

# If pane is zoomed, unzoom first to restore layout geometry
zoomed=$(tmux display-message -p '#{window_zoomed_flag}')
[ "$zoomed" = "1" ] && tmux resize-pane -Z

# Get current pane geometry + cursor in one call
eval "$(tmux display-message -p \
    'cur_id=#{pane_id} cur_left=#{pane_left} cur_top=#{pane_top} cur_w=#{pane_width} cur_h=#{pane_height} cur_x=#{cursor_x} cur_y=#{cursor_y} in_mode=#{pane_in_mode} copy_x=#{copy_cursor_x} copy_y=#{copy_cursor_y}')"

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
done < <(tmux list-panes -F '#{pane_id} #{pane_left} #{pane_top} #{pane_width} #{pane_height}')

[ -n "$best_id" ] && tmux select-pane -t "$best_id"
exit 0
