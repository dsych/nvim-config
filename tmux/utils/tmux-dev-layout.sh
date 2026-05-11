#!/usr/bin/env bash
# tmux-dev-layout.sh - 3-pane dev layout (editor + utilities)
# Invoked by: prefix + v
#
# Layout:
#   ┌──────────────────────────┐
#   │       nvim . (editor)    │  50% height, full width
#   ├────────────┬─────────────┤
#   │  w_arch    │   shell     │  50% height, 50/50 width
#   └────────────┴─────────────┘

set -euo pipefail

PANE_ID=$(tmux display-message -p '#{pane_id}')
WINDOW_ID=$(tmux display-message -p '#{window_id}')
CURRENT_CMD=$(tmux display-message -p '#{pane_current_command}')

# 1. Kill all other panes in this window
for pane in $(tmux list-panes -t "$WINDOW_ID" -F '#{pane_id}'); do
    [ "$pane" != "$PANE_ID" ] && tmux kill-pane -t "$pane" 2>/dev/null || true
done

# 2. Build the layout
# The source pane becomes the top (editor) pane.
# Split bottom-left (50% height from top pane)
tmux split-window -v -l 50% -t "$PANE_ID"
BOTTOM_LEFT=$(tmux display-message -p '#{pane_id}')

# Split bottom-right from bottom-left (50% width)
tmux split-window -h -l 50% -t "$BOTTOM_LEFT"
BOTTOM_RIGHT=$(tmux display-message -p '#{pane_id}')

# 3. Tag bottom panes for auto-resize hook
tmux set-option -p -t "$BOTTOM_LEFT" @dev-layout-bottom 1
tmux set-option -p -t "$BOTTOM_RIGHT" @dev-layout-bottom 1

# 4. Top pane: launch nvim if no program is already running
if [ "$CURRENT_CMD" = "fish" ] || [ "$CURRENT_CMD" = "bash" ] || [ "$CURRENT_CMD" = "zsh" ]; then
    tmux send-keys -t "$PANE_ID" 'nvim .' Enter
fi

# 5. Bottom-left: launch w_arch if available
tmux send-keys -t "$BOTTOM_LEFT" 'type -q w_arch 2>/dev/null && w_arch || echo "error: w_arch alias not found"' Enter

# 6. Bottom-right: just a shell (already is one)

# Focus back to editor pane
tmux select-pane -t "$PANE_ID"
