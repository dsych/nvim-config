# fish_clipboard_copy - copy to the tmux buffer; tmux puts it on the system clipboard
#
# Overrides fish's built-in fish_clipboard_copy (ctrl-x, "*yy, "+yy, visual "*y,
# and the vi yank hook in fish_user_key_bindings.fish). Inside tmux the text goes
# to `tmux load-buffer -w`, which creates a tmux paste buffer and sends it to the
# terminal's clipboard (OSC 52, set-clipboard on in tmux.conf) - the same path
# copy-mode `y` uses, so it works over ssh and in nested tmux. Outside tmux it
# falls back to the built-in function.
#
# Usage: fish_clipboard_copy            # selection, or the whole command line
#        printf %s text | fish_clipboard_copy

# Keep fish's own implementation as the outside-tmux fallback
status get-file functions/fish_clipboard_copy.fish 2>/dev/null \
    | string replace -r '^function fish_clipboard_copy\b' 'function __fish_clipboard_copy_builtin' \
    | source

function fish_clipboard_copy --description "Copy to the tmux buffer + system clipboard"
    if not set -q TMUX
        if functions -q __fish_clipboard_copy_builtin
            __fish_clipboard_copy_builtin
        end
        return
    end
    set -l text
    if isatty stdin
        # Same text the built-in copies: the selection, else the command line
        set text (commandline --current-selection | fish_indent --only-indent | string collect)
        test -n "$text"; or set text (commandline | fish_indent --only-indent | string collect)
    else
        while read -lz line
            set -a text $line
        end
    end
    test -n "$text"; or return 0
    printf '%s' $text | command tmux load-buffer -w -
end
