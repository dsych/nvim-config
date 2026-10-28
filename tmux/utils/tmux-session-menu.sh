#!/usr/bin/env bash
# tmux-session-menu.sh - session picker with a one-key hint per session
#
# Opens a tmux menu (display-menu) listing every session. Each session has a
# single-character key shown in brackets just before the name (tmux also
# repeats it at the right edge); pressing it switches to that
# session. Arrows / Tab + Enter and the mouse work too, q / Esc cancels.
# The menu opens on this client's previous session, so Enter alone flips
# between the two sessions you're working in.
#
# Hints follow session-name order (tmux's own list order), so a session keeps
# its key as long as the set of sessions doesn't change.
#
# Agent attention: a pane where pi needs you carries @pi-attention (set by the
# tmux-attention pi extension only while you weren't looking; tmux.conf clears
# it when you arrive at the window): "ask" while pi asks you something, "done"
# once a run ended. Such a session gets a mark in a column after its name, ?
# (asks) before @ (your turn), plus the count when several agents wait, and
# picking it goes to the agent's pane: the oldest asking one, else the oldest.
# The column only appears while some session has a mark. A mark whose pi is
# gone (killed without cleaning up) is skipped and removed.
#
# Usage (from a key binding: prefix s): tmux-session-menu.sh <client_name>

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

client="${1:-}"
[ -n "$client" ] || exit 0

# Right-hand home row first, then the left. Item keys take precedence over the
# menu's own keys (tmux menu.c), so j and k pick sessions instead of moving;
# arrows / Tab still move. Not g G q: they stay free for jumping to the top /
# bottom and for cancelling.
KEYS="jkl;asdfhweruiotpyzxcvbnm1234567890"

# Look the client up: display-message -c only picks where to display, its
# formats would come from another client. client_last_session is the session
# this client was in before (what `switch-client -l` goes to).
IFS=$'\t' read -r current previous < <(tmux list-clients -F '#{client_name}	#{client_session}	#{client_last_session}' |
    awk -F'\t' -v c="$client" '$1 == c { print $2 "\t" $3; exit }')
# None yet (new client) or it was killed: the most recently used other session
if [ -z "$previous" ] || [ "$previous" = "$current" ] || ! tmux has-session -t "=$previous" 2>/dev/null; then
    previous=$(tmux list-sessions -F '#{session_last_attached}	#{session_name}' |
        awk -F'\t' -v cur="$current" '$2 != cur' | sort -rn | head -1 | cut -f2-)
fi

# Measure and render the same snapshot so every row shares column widths.
# tmux reports display cells, unlike shell string lengths / printf widths,
# which count bytes or characters and misalign non-ASCII session names.
# The last field lists the session's marked panes: state:since:pid:pane ...
sessions=$(tmux list-sessions -F '#{session_id}	#{session_name}	#{session_windows}	#{session_attached}	#{w:session_name}	#{W:#{P:#{?#{@pi-attention},#{@pi-attention}:#{@pi-attention-since}:#{@pi-attention-pid}:#{pane_id} ,}}}')
[ -n "$sessions" ] || exit 0
name_width=18
windows_width=2
mark_width=0
marks=() targets=()   # by row (no associative arrays: macOS's /bin/bash is 3.2)
stale=()
row=0
while IFS=$'\t' read -r id name windows attached width agents; do
    (( width > name_width )) && name_width=$width
    (( ${#windows} > windows_width )) && windows_width=${#windows}
    count=0 best="" best_since=0 target=""
    for agent in $agents; do
        IFS=: read -r state since pid pane <<< "$agent"
        if ! kill -0 "$pid" 2>/dev/null; then stale+=("$pane"); continue; fi
        count=$((count + 1))
        # asking outranks done; the oldest of the same kind
        if [ -z "$best" ] || { [ "$state" = ask ] && [ "$best" != ask ]; } ||
            { [ "$state" = "$best" ] && (( since < best_since )); }; then
            best=$state best_since=$since target=$pane
        fi
    done
    if (( count > 0 )); then
        mark="@"; [ "$best" = ask ] && mark="?"
        (( count > 1 )) && mark+=$count
        marks[row]=$mark targets[row]=$target
        (( ${#mark} > mark_width )) && mark_width=${#mark}
    fi
    row=$((row + 1))
done <<< "$sessions"
if (( ${#stale[@]} > 0 )); then
    clean=()
    for pane in "${stale[@]}"; do clean+=(set-option -p -t "$pane" -u @pi-attention \;); done
    tmux "${clean[@]}" 2>/dev/null
fi

args=()
i=0
start=0
while IFS=$'\t' read -r id name windows attached width agents; do
    key="${KEYS:i:1}"   # past the last key: no hint, still pickable with arrows
    current_mark=" "
    note=""
    if [ "$name" = "$current" ]; then
        current_mark="*"
    elif [ "$attached" -gt 0 ]; then
        note="  (attached)"
    fi
    [ "$name" = "$previous" ] && start=$i
    # The attention column (only while some session is marked) sits after the name
    column=""
    (( mark_width > 0 )) && column=$(printf '%-*s ' "$mark_width" "${marks[i]:-}")
    # Key hint sits right beside the name so no need to scan to the line end
    label=$(printf '[%s] %s %s%*s %s%*s win%s' "${key:- }" "$current_mark" "$name" "$((name_width - width))" "" "$column" "$windows_width" "$windows" "$note")
    # Menu labels are formats: a literal # must be doubled. A bare ; argument
    # is tmux's command separator, so the ; key is passed as \;
    menu_key=$key; [ "$key" = ";" ] && menu_key='\;'
    args+=("${label//#/##}" "$menu_key" "switch-client -t '${targets[i]:-$id}'")
    i=$((i + 1))
done <<< "$sessions"

[ "$i" -gt 0 ] || exit 0
tmux display-menu -c "$client" -T '#[align=centre] Sessions ' -x C -y C -C "$start" "${args[@]}"
