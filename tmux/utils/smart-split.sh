#!/usr/bin/env bash
# tmux-smart-split: splits a pane, detecting SSH sessions to open the new pane on the same remote host.
# Usage: tmux-smart-split [-h|-v] [command]
#   -h: horizontal split (side by side)
#   -v: vertical split (top/bottom, default)
#   command: optional command to run in the new pane (instead of a shell)

set -euo pipefail

direction="${1:--v}"
shift || true
extra_cmd="${*:-}"

pane_pid=$(tmux display -p '#{pane_pid}')
pane_path=$(tmux display -p '#{pane_current_path}')

# Walk the process tree from the pane's shell to find an SSH process
find_ssh_target() {
    local pid="$1"

    # Check direct children of the pane's process for an ssh connection
    local children
    children=$(pgrep -P "$pid" 2>/dev/null || true)

    for child in $children; do
        local cmd
        cmd=$(ps -o args= -p "$child" 2>/dev/null || true)

        if [[ "$cmd" =~ ^ssh[[:space:]] ]]; then
            parse_ssh_target "$cmd"
            return $?
        fi

        # Recurse one level (for cases like: bash -> ssh)
        local grandchildren
        grandchildren=$(pgrep -P "$child" 2>/dev/null || true)
        for gc in $grandchildren; do
            local gc_cmd
            gc_cmd=$(ps -o args= -p "$gc" 2>/dev/null || true)
            if [[ "$gc_cmd" =~ ^ssh[[:space:]] ]]; then
                parse_ssh_target "$gc_cmd"
                return $?
            fi
        done
    done

    return 1
}

# Parse an SSH command line to extract user@host target
parse_ssh_target() {
    local cmd="$1"
    local skip_next=false

    for arg in $cmd; do
        if [[ "$skip_next" == true ]]; then
            skip_next=false
            continue
        fi
        # SSH flags that take an argument
        if [[ "$arg" =~ ^-[bcDEeFIiJLlmOopQRSWw]$ ]]; then
            skip_next=true
            continue
        fi
        # Combined flag+value like -p22 or -oOption
        if [[ "$arg" =~ ^-[bcDEeFIiJLlmOopQRSWw].+ ]]; then
            continue
        fi
        # Skip other flags
        if [[ "$arg" =~ ^- ]]; then
            continue
        fi
        # Skip "ssh" itself
        if [[ "$arg" == "ssh" ]]; then
            continue
        fi
        # This should be the target (user@host or host)
        echo "$arg"
        return 0
    done

    return 1
}

# Try to get the remote working directory by querying the remote tmux session
get_remote_cwd() {
    local target="$1"
    # Query the remote tmux for the active pane's current path
    # This works when the remote is running tmux (our connect.sh setup)
    ssh -o ConnectTimeout=2 -o BatchMode=yes "$target" \
        "tmux display -p '#{pane_current_path}' 2>/dev/null" 2>/dev/null || true
}

ssh_target=$(find_ssh_target "$pane_pid" || true)

if [[ -n "$ssh_target" ]]; then
    # Current pane is running SSH — open split on the same remote
    remote_cwd=$(get_remote_cwd "$ssh_target")

    if [[ -n "$extra_cmd" ]]; then
        if [[ -n "$remote_cwd" ]]; then
            tmux split-window "$direction" "ssh -t $ssh_target 'cd \"$remote_cwd\" && ($extra_cmd)'"
        else
            tmux split-window "$direction" "ssh -t $ssh_target '$extra_cmd'"
        fi
    else
        if [[ -n "$remote_cwd" ]]; then
            tmux split-window "$direction" "ssh -t $ssh_target 'cd \"$remote_cwd\" && exec \$SHELL -l'"
        else
            tmux split-window "$direction" "ssh $ssh_target"
        fi
    fi
else
    # Normal local split
    if [[ -n "$extra_cmd" ]]; then
        tmux split-window "$direction" -c "$pane_path" "$extra_cmd"
    else
        tmux split-window "$direction" -c "$pane_path"
    fi
fi

