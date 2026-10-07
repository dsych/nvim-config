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
# The same wrapper also runs the hyperlink peek check (tmux-link-peek.sh): when
# the link under the cursor changed, show/update/hide its URL. The check is a
# format comparison inside tmux; the script only runs on a change. Disable with
#   set -g @link-peek off
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mark=""; peek=""
# Guarded so a command that left copy mode (e.g. scroll-down at the bottom
# with copy-mode -e) doesn't produce a "not in a mode" error.
[ "$(tmux show-options -gqv @copy-cursorline)" != "off" ] &&
    mark="if-shell -F '#{||:#{==:#{pane_mode},copy-mode},#{==:#{pane_mode},view-mode}}' 'send-keys -X set-mark'"
# Remember the new link first, so a burst of moves starts one update per change
[ "$(tmux show-options -gqv @link-peek)" != "off" ] &&
    peek="if-shell -F '#{&&:#{!:#{@link-peek-float}},#{!=:#{copy_cursor_hyperlink},#{@link-peek-url}}}' { set-option -wF @link-peek-url '#{copy_cursor_hyperlink}' ; run-shell -b '$SCRIPT_DIR/tmux-link-peek.sh update #{pane_id}' }"
[ -z "$mark$peek" ] && exit 0

tmp=$(mktemp "${TMPDIR:-/tmp}/tmux-cursorline.XXXXXX") || exit 1
trap 'rm -f "$tmp"' EXIT

# Bindings already wrapped by an earlier run (config reload) are skipped; ones
# wrapped before the peek check existed (they have the mark only) get it added.
for table in copy-mode-vi copy-mode; do
    tmux list-keys -T "$table" 2>/dev/null
done | awk -v mark="$mark" -v peek="$peek" '
    function wrap(line, cmds,    n, i, c, brace, out) {
        n = split(cmds, c, "\n"); brace = (line ~ / \{ .* \}$/)
        out = brace ? substr(line, 1, length(line) - 2) : line
        for (i = 1; i <= n; i++) if (c[i] != "") out = out (brace ? " ; " : " \\; ") c[i]
        print out (brace ? " }" : "")
    }
    /tmux-link-peek|jump-to-mark|cancel/ { next }
    !/send-keys -[A-Za-z]*X/              { next }
    /if-shell -F .*set-mark/              { if (peek != "") wrap($0, peek); next }
    /set-mark/                            { next }
                                          { wrap($0, mark "\n" peek) }
' > "$tmp"

[ -s "$tmp" ] && tmux source-file "$tmp"
exit 0
