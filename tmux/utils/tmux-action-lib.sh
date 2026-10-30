#!/usr/bin/env bash
# Shared action routing. Sourced by the URL/clipboard entry points.
# @action-environment is local/remote, set by tmux.conf. A session override
# wins over the global value. TMUX_ACTION_TARGET pins popup actions to their
# originating session; absent a setting, fall back to the SSH environment.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

action_environment() {
    local mode
    if [ -n "${TMUX_ACTION_TARGET:-}" ]; then
        mode=$(tmux show-options -qv -t "$TMUX_ACTION_TARGET" @action-environment 2>/dev/null)
    else
        mode=$(tmux show-options -qv @action-environment 2>/dev/null)
    fi
    # show-options for a named user option does not report inherited values.
    # Read the global default explicitly when the session has no override.
    if [ -z "$mode" ]; then
        mode=$(tmux show-options -gqv @action-environment 2>/dev/null)
    fi
    case "$mode" in
        local|remote) printf '%s\n' "$mode" ;;
        *) if [ -n "${SSH_CONNECTION:-}${SSH_CLIENT:-}${SSH_TTY:-}" ]; then
               printf 'remote\n'
           else
               printf 'local\n'
           fi ;;
    esac
}

action_notice() {
    printf '%s\n' "$*" >&2
    tmux display-message -l "$*" 2>/dev/null || true
}

# URL opening never evaluates the URL as shell code. A local headless Linux
# session must not silently route into the SSH relay.
action_open_local() {
    local url=$1 os
    os=$(uname -s)
    case "$os" in
        Darwin)
            if command -v open >/dev/null 2>&1 && open "$url"; then return 0; fi ;;
        Linux)
            if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
                if command -v xdg-open >/dev/null 2>&1 && xdg-open "$url"; then return 0; fi
                if command -v gio >/dev/null 2>&1 && gio open "$url"; then return 0; fi
            fi ;;
    esac
    action_notice "Cannot open URL locally ($os): check your desktop session and browser opener"
    return 1
}
