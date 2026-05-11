#!/usr/bin/env bash
# tmux-command-palette.sh - Command palette with fzf
# Custom actions at the top, followed by all tmux commands

# ── Helpers for complex actions ──────────────────────────────────────
switch_session() {
    local s
    s=$(tmux list-sessions -F '#{session_name}' | fzf --reverse --header='Switch Session')
    [ -n "$s" ] && tmux switch-client -t "$s"
}

new_session() {
    tmux new-session -d -s "$1" && tmux switch-client -t "$1"
}

prompt_and_run() {
    local prompt="$1"; shift
    local input
    read -r -p "$prompt: " input
    [ -n "$input" ] && "$@" "$input"
}

# ── Custom actions ───────────────────────────────────────────────────
# Format: "Label ;; display_hint ;; shell_command"
#    or:  "Label ;; tmux_command"              (2 fields = display is the command, run as tmux)
#
# 2 fields → displayed as "⚡ Label → tmux_command",  executed as: tmux <tmux_command>
# 3 fields → displayed as "⚡ Label → display_hint",  executed as: eval <shell_command>

ACTIONS=(
    "Dev Layout           ;; run-shell               ;; tmux run-shell \"\$HOME/.config/tmux-ssh/tmux-dev-layout.sh\""
    "Switch Session       ;; switch-client            ;; switch_session"
    "Reload Config        ;; source-file              ;; tmux source-file ~/.tmux.conf"
    "SSH Connect          ;; connect.sh               ;; tmux run-shell \"\$HOME/.config/tmux-ssh/connect.sh\""
    "Kill Current Pane    ;; kill-pane"
    "Kill Other Panes     ;; kill-pane -a"
    "Kill Current Window  ;; kill-window"
    "Kill Current Session ;; kill-session"
    "New Window           ;; new-window"
    "New Session          ;; new-session              ;; prompt_and_run 'Session name' new_session"
    "Rename Window        ;; rename-window            ;; prompt_and_run 'Window name' tmux rename-window"
    "Rename Session       ;; rename-session           ;; prompt_and_run 'Session name' tmux rename-session"
    "Toggle Mouse         ;; set mouse"
    "Toggle Pane Zoom     ;; resize-pane -Z"
    "Move Pane Left       ;; swap-pane -U"
    "Move Pane Right      ;; swap-pane -D"
    "Detach               ;; detach-client"
    "mwinit               ;; split-window -v 'mwinit -f'"
    "Agent Deck           ;; agent-deck               ;; AGENT_DECK_ALLOW_OUTER_TMUX=1 agent-deck"
    "Edit Command Palette  ;; nvim palette             ;; nvim \"\${BASH_SOURCE[0]}\""
    "Edit tmux.conf        ;; nvim tmux.conf           ;; nvim ~/.tmux.conf"
)

# ── Build fzf list ──────────────────────────────────────────────────
build_custom_list() {
    for entry in "${ACTIONS[@]}"; do
        local label hint
        label="${entry%% ;; *}"
        local rest="${entry#* ;; }"
        # Extract display hint (first field after label)
        hint="${rest%% ;; *}"
        printf "⚡ %-22s → %s\n" "$label" "$hint"
    done
}

tmux_cmds=$(tmux list-commands -F '#{command_list_name} #{command_list_alias}' | \
    awk '{
        cmd = $1
        alias = $2
        if (alias != "")
            printf "  %-25s → %s (alias: %s)\n", cmd, cmd, alias
        else
            printf "  %-25s → %s\n", cmd, cmd
    }')

selected=$( (build_custom_list; echo "$tmux_cmds") | fzf \
    --reverse \
    --header="Command Palette" \
    --height=100% \
    --no-info)

[ -z "$selected" ] && exit 0

# ── Execute ─────────────────────────────────────────────────────────
if [[ "$selected" == "⚡"* ]]; then
    # Match selected label back to ACTIONS entry
    for entry in "${ACTIONS[@]}"; do
        label="${entry%% ;; *}"
        if [[ "$selected" == *"$label"* ]]; then
            rest="${entry#* ;; }"
            if [[ "$rest" == *" ;; "* ]]; then
                # 3 fields: eval the shell command (third field)
                cmd="${rest#* ;; }"
                eval "$cmd"
            else
                # 2 fields: run as tmux command
                tmux $rest
            fi
            exit 0
        fi
    done
else
    # Generic tmux command: let user edit the full command line
    cmd=$(echo "$selected" | sed 's/.*→ //; s/ (alias:.*//')
    read -r -e -p "> " -i "$cmd " full_cmd
    [ -n "$full_cmd" ] && tmux $full_cmd
fi
