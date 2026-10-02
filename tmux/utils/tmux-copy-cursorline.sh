#!/usr/bin/env bash
# Copy-mode cursor line.
#
# tmux has no cursor-line option, but it does highlight the whole line holding
# the copy-mode mark (copy-mode-mark-style). This script makes the mark follow
# the cursor: every copy-mode binding that moves the cursor is re-bound to also
# run `set-mark`. The tmux.conf hook on pane-mode-changed sets the initial mark
# when copy mode starts, and tmux-jump.sh sets it after a jump.
#
# Cost: the mark can no longer be used for jump-to-mark (M-x).
#
# Run from tmux.conf with `run-shell` *after* every copy-mode binding and after
# TPM, so plugin bindings are wrapped too. Idempotent: already-wrapped
# bindings are skipped, so reloading the config is safe. Disable with
#   set -g @copy-cursorline off
#
# How bindings are rewritten (list-keys output is valid tmux syntax, so each
# line is re-sourced with the mark command added):
#   plain:   bind-key ... j send-keys -X cursor-down
#        ->  bind-key ... j send-keys -X cursor-down \; <mark>
#   prompt:  bind-key ... / command-prompt ... { send-keys -X search-forward -- "%%" }
#        ->  bind-key ... / command-prompt ... { send-keys -X search-forward -- "%%" ; <mark> }
# Skipped: bindings without `send-keys -X` (count prompts, run-shell, ...),
# bindings that leave copy mode (*cancel*), jump-to-mark, already wrapped ones.

set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

[ "$(tmux show-options -gqv @copy-cursorline)" = "off" ] && exit 0

# Guarded so a command that left copy mode (e.g. scroll-down at the bottom
# with copy-mode -e) doesn't produce a "not in a mode" error.
mark="if-shell -F '#{||:#{==:#{pane_mode},copy-mode},#{==:#{pane_mode},view-mode}}' 'send-keys -X set-mark'"

tmp=$(mktemp "${TMPDIR:-/tmp}/tmux-cursorline.XXXXXX") || exit 1
trap 'rm -f "$tmp"' EXIT

for table in copy-mode-vi copy-mode; do
    tmux list-keys -T "$table" 2>/dev/null
done | awk -v mark="$mark" '
    /set-mark|jump-to-mark|cancel/ { next }
    !/send-keys -[A-Za-z]*X/       { next }
    / \{ .* \}$/                   { sub(/ \}$/, " ; " mark " }"); print; next }
                                   { print $0 " \\; " mark }
' > "$tmp"

[ -s "$tmp" ] && tmux source-file "$tmp"
exit 0
