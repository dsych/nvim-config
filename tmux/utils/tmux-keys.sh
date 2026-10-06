#!/usr/bin/env bash
# tmux-keys.sh - fuzzy-searchable list of every tmux key binding (all tables).
# $1 = client name of the caller (popup steals context, so it is passed in).
#
# Rows: TABLE  KEY  NOTE-or-COMMAND. The preview pane shows the full command.
# Enter on a prefix/root binding fires it in the caller's client once the popup
# has closed (send-keys -K replays the key through the binding tables).

CLIENT="${1:-}"
TAB=$'\t'

rows() {
    # table, key, prefix, note, command -> tab-separated, newlines/tabs squashed.
    tmux list-keys -F "#{key_table}${TAB}#{key_string}${TAB}#{key_prefix}${TAB}#{key_note}${TAB}#{key_command}" |
    awk -F'\t' -v OFS='\t' '
        function rank(t) { return t=="prefix" ? 0 : t=="root" ? 1 : 2 }
        {
            cmd  = $5
            desc = ($4 != "") ? $4 "  ·  " cmd : cmd
            key  = ($1 == "prefix") ? $3 " " $2 : $2
            # cols: rank table key prefix cmd desc display (rank dropped by cut)
            printf "%d\t%s\t%s\t%s\t%s\t%s\t%-11s %-14s %s\n", rank($1), $1, $2, $3, cmd, desc, $1, key, desc
        }' |
    sort -t"$TAB" -s -k1,1n |
    cut -f2-
}

# Fields after cut: 1 table, 2 key, 3 prefix, 4 cmd, 5 desc, 6 display.
selected=$(rows | fzf \
    --reverse \
    --delimiter="$TAB" --with-nth=6 \
    --header="Key bindings  (Enter: run prefix/root binding, Esc: close)" \
    --preview='printf "%s  %s  (prefix %s)\n\n%s\n" {1} {2} {3} {4}' \
    --preview-window='down:6:wrap' \
    --no-info --exact 2>/dev/null)

[ -z "$selected" ] && exit 0

IFS="$TAB" read -r table key prefix _ <<<"$selected"

case "$table" in
    prefix) keys=("$prefix" "$key") ;;
    root)   keys=("$key") ;;
    *)      tmux display-message "Key table '$table' only applies inside that mode; not run."; exit 0 ;;
esac
case "$key" in
    Mouse*|Double*|Triple*|Wheel*|Second*) tmux display-message "Mouse binding; not run."; exit 0 ;;
esac

# Replay after the popup closes (keys sent now would go to the popup itself).
# Hand the delayed send-keys to the tmux server: a background job started from
# inside the popup is killed when the popup exits.
printf -v quoted ' %q' "${keys[@]}"
quoted=${quoted//#/##}   # run-shell expands #{...} formats
tmux run-shell -b "sleep 0.25; tmux send-keys -K ${CLIENT:+-c $(printf %q "$CLIENT")}$quoted"
