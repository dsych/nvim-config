#!/usr/bin/env bash
# tmux-session-menu.sh - session picker with a one-key hint per session
#
# Opens a tmux menu (display-menu) listing every session. Each session has a
# single-character key shown on the right; pressing it switches to that
# session. Arrows / j k + Enter and the mouse work too, q / Esc cancels.
# The menu opens on this client's previous session, so Enter alone flips
# between the two sessions you're working in.
#
# Hints follow session-name order (tmux's own list order), so a session keeps
# its key as long as the set of sessions doesn't change.
#
# Usage (from a key binding: prefix s): tmux-session-menu.sh <client_name>

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

client="${1:-}"
[ -n "$client" ] || exit 0

# Home row first. Not j k g G q: the menu uses them for moving and cancelling.
KEYS="asdfhlweruiotpyzxcvbnm1234567890"

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

args=()
i=0
start=0
while IFS=$'\t' read -r id name windows attached; do
    key="${KEYS:i:1}"   # past the last key: no hint, still pickable with arrows
    mark=" "
    note=""
    if [ "$name" = "$current" ]; then
        mark="*"
    elif [ "$attached" -gt 0 ]; then
        note="  (attached)"
    fi
    [ "$name" = "$previous" ] && start=$i
    label=$(printf '%s %-18s %2s win%s' "$mark" "$name" "$windows" "$note")
    # Menu labels are formats: a literal # must be doubled
    args+=("${label//#/##}" "$key" "switch-client -t '$id'")
    i=$((i + 1))
done < <(tmux list-sessions -F '#{session_id}	#{session_name}	#{session_windows}	#{session_attached}')

[ "$i" -gt 0 ] || exit 0
tmux display-menu -c "$client" -T '#[align=centre] Sessions ' -x C -y C -C "$start" "${args[@]}"
