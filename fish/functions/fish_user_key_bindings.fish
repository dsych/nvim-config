# fish_user_key_bindings - run by fish after it (re)loads the key bindings
#
# Vi yanks (yy, yw, y$, yiw, yf), visual y, ...) also go to the clipboard, like
# vim's clipboard=unnamedplus: fish_clipboard_copy puts them in the tmux buffer
# and tmux puts them on the system clipboard. Deletes are not copied.
function fish_user_key_bindings
    __yank_to_clipboard_setup
end

# fish keeps yanked text in its kill ring, which scripts can't read: read the
# newest entry by yanking it once more, then undo that.
function __yank_to_clipboard --description "Copy the newest kill-ring entry to the clipboard"
    set -l before (commandline | string collect -N)
    set -l cursor (commandline -C)
    commandline -f yank
    set -l after (commandline | string collect -N)
    test "$after" = "$before"; and return # kill ring empty
    set -l n (math (string length -- "$after") - (string length -- "$before"))
    set -l text (string sub -s (math $cursor + 1) -l $n -- "$after" | string collect -N)
    commandline -f undo
    commandline -C $cursor # undo can leave the cursor one column off
    printf '%s' "$text" | fish_clipboard_copy
end

function __yank_to_clipboard_setup
    # `commandline -f` runs immediately only while nothing is queued; once a
    # repaint is queued, later editor commands wait until the key binding is
    # done, so the copy step would read the command line too early. Two stock
    # repaints get in the way of operator yanks (y + motion: yy, yw, 3ye, yf), ...):
    # - fish_vi_start_operator (the `y` key) queues one, and since `y` also
    #   starts `y$`, `yiw`, ... it only runs together with the motion key.
    #   Drop it: the motion repaints when it finishes.
    # - fish_vi_exec_motion (the motion) ends with one. Run the copy before it.
    #   Its selection yanks call fish_vi_yank_selection, which switches to the
    #   exclusive cursor mode around its kill+yank. In stock fish those run late
    #   (after the switch back) for motions typed straight after `y`, but on time
    #   for f/F/t/T jumps (their mode switch queues nothing). Copy that, so the
    #   cursor ends where stock fish puts it.
    if functions fish_vi_start_operator | string match -q -- '*commandline -f repaint-mode*'
        functions fish_vi_start_operator | string replace -- 'commandline -f repaint-mode' '' | source
    end
    if functions -q fish_vi_exec_motion; and not functions -q __yank_to_clipboard_exec_motion
        functions fish_vi_exec_motion \
            | string replace -r -- '^function fish_vi_exec_motion\b' 'function __yank_to_clipboard_exec_motion' \
            | string replace -- 'commandline -f repaint-mode' '' \
            | string replace -- fish_vi_yank_selection __yank_to_clipboard_yank_selection | source
        function __yank_to_clipboard_yank_selection
            if test "$__yank_to_clipboard_mode" = operator
                commandline -f kill-selection yank
            else
                fish_vi_yank_selection
            end
        end
        function fish_vi_exec_motion
            set -l op $__fish_vi_operator
            set -g __yank_to_clipboard_mode $fish_bind_mode
            __yank_to_clipboard_exec_motion $argv
            set -l rc $status
            test "$op" = yank; and __yank_to_clipboard
            commandline -f repaint-mode
            return $rc
        end
    end
    # Direct yank bindings (y$, y0, yiw, yib, visual y, ...): append the copy
    # step. Kill-then-yank sequences only: a bare `yank` (ctrl-y) is a paste.
    for mode in default visual
        for line in (bind --preset -M $mode | string match -r -- '^bind --preset .*(?:kill-[a-z-]+ yank|fish_vi_yank_selection).*$')
            string match -qr -- 'fish_vi_start_operator|fish_clipboard_copy|__yank_to_clipboard' $line; and continue
            eval (string replace -- 'bind --preset ' 'bind ' $line) __yank_to_clipboard
        end
    end
end
