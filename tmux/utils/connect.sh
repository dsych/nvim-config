#!/usr/bin/env bash
# connect.sh - prefix+R (local machine only): pick an SSH target (fzf), then
# connect to it in this window, which closes when ssh exits.
#
# The targets are machine-local and not in the config repo (git-ignored):
# ~/.config/tmux/hosts.json, next to snippets.json, because utils/ is a link
# into the repo. The old place, utils/hosts.json, is still read. Format:
#   [{"name": "dev", "username": "me", "remote_address": "dev.example.com",
#     "additional_ssh_options": "-A"}]
# Optional laptop SSH access: "laptop_access": {"enabled": true,
# "remote_port": 2222, "local_port": 22}. Forward binds remote loopback
# and dials the laptop's loopback SSH service.
# See ../LAPTOP-ACCESS.md for Remote Login, keys, and revocation.
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# This window closes when the script exits: keep it open on a failure so the
# error can be read (replaced by the ssh cleanup below)
trap 'status=$?; [[ $status -eq 0 ]] || { printf "\nprefix+R failed (exit %s). Press Enter to close.\n" "$status"; read -r _ || true; }' EXIT

HOSTS_FILE="${TMUX_SSH_HOSTS:-$HOME/.config/tmux/hosts.json}"
if [[ -z "${TMUX_SSH_HOSTS:-}" && ! -f "$HOSTS_FILE" && -f "$HOME/.config/tmux/utils/hosts.json" ]]; then
    HOSTS_FILE="$HOME/.config/tmux/utils/hosts.json"
fi
SHARED_DIR="${TMUX_SSH_SHARED:-$HOME/ssh_shared}"

if [[ ! -f "$HOSTS_FILE" ]]; then
    echo "No SSH targets: $HOSTS_FILE doesn't exist (format: see the top of $0)" >&2
    exit 1
fi

# Build display lines: "name | user@host"
entries=$(jq -r '.[] | "\(.name) | \(.username)@\(.remote_address)"' "$HOSTS_FILE")

# fzf picker; Esc (exit 130) or no match closes this temporary window
selected=$(echo "$entries" | fzf \
    --prompt="SSH Target> " \
    --header="prefix+R | SSH Connect" \
    --height=100% \
    --reverse \
    --border \
    --no-info) || exit 0
[[ -z "$selected" ]] && exit 0

# Extract name from selection
name="${selected%% |*}"

# Check if any window already has @ssh_target set to this name
existing_window=$(
    tmux list-windows -F '#{window_id}' | while read -r wid; do
        val=$(tmux show-option -wqv -t "$wid" @ssh_target 2>/dev/null)
        if [[ "$val" == "$name" ]]; then
            echo "$wid"
            break
        fi
    done
)

if [[ -n "$existing_window" ]]; then
    # Switch to existing SSH window, this window closes on exit
    tmux select-window -t "$existing_window"
    exit 0
fi

# Pull connection details from JSON
read -r user host opts < <(
    jq -r --arg n "$name" \
        '.[] | select(.name == $n) | "\(.username) \(.remote_address) \(.additional_ssh_options // "")"' \
        "$HOSTS_FILE"
)

# Explicit opt-in only. Validate before doing remote work, not halfway through
# starting a persistent forwarding session. Ports must be numeric integers;
# don't interpolate arbitrary JSON strings into network endpoints.
laptop_ports=$(jq -er --arg n "$name" '
    def port($lo): type == "number" and . == floor and . >= $lo and . <= 65535;
    .[] | select(.name == $n) | (.laptop_access // {}) |
    if type != "object" then error("laptop_access must be an object")
    elif (.enabled // false) == false then "disabled"
    elif .enabled != true then error("laptop_access.enabled must be a boolean")
    else (if has("remote_port") then .remote_port else 2222 end) as $remote |
         (if has("local_port") then .local_port else 22 end) as $local |
         if ($remote | port(1024)) and ($local | port(1))
         then [$remote, $local] | @tsv
         else error("Invalid laptop_access ports (remote: 1024-65535, local: 1-65535)") end
    end
' "$HOSTS_FILE")

# Sync tmux config directory to remote before connecting, unless the remote
# manages its own: a symlinked tmux.conf means it points into a checkout of
# the config repo there, and rsync would replace the links with copies.
# shellcheck disable=SC2086
remote_cfg=$(ssh $opts "${user}@${host}" 'mkdir -p ~/.config/tmux; test -L ~/.config/tmux/tmux.conf && echo linked || echo plain' 2>/dev/null)
if [ "$remote_cfg" = "linked" ]; then
    echo "Remote tmux config is symlinked (managed there); skipping sync"
else
    echo "Syncing tmux config to ${host}..."
    # shellcheck disable=SC2086
    rsync -aqL -e "ssh $opts" "$HOME/.config/tmux/" "${user}@${host}:~/.config/tmux/" || echo "Warning: failed to sync tmux config"
fi

# ======================== BIDIRECTIONAL SHARED FOLDER (MUTAGEN) ======================== #
# Uses mutagen to sync ~/ssh_shared bidirectionally between local and remote.
# Session is named by hostname for idempotency and cleaned up on exit.

MUTAGEN_SESSION="ssh-shared-${host%%.*}"

start_shared_sync() {
    if ! command -v mutagen &>/dev/null; then
        tmux display-message -d 5000 "⚠ ssh_shared: mutagen not installed (brew install mutagen-io/mutagen/mutagen)"
        return 1
    fi

    # Ensure local shared dir exists
    mkdir -p "$SHARED_DIR" || {
        tmux display-message -d 5000 "⚠ ssh_shared: failed to create $SHARED_DIR"
        return 1
    }

    # Ensure remote shared dir exists
    # shellcheck disable=SC2086
    if ! ssh $opts "${user}@${host}" "mkdir -p ~/ssh_shared" 2>/dev/null; then
        tmux display-message -d 5000 "⚠ ssh_shared: failed to create remote ~/ssh_shared"
        return 1
    fi

    # Terminate any stale session with the same name
    mutagen sync terminate "$MUTAGEN_SESSION" 2>/dev/null || true

    # Create bidirectional sync session
    if mutagen sync create \
        "$SHARED_DIR" \
        "${user}@${host}:~/ssh_shared" \
        --name="$MUTAGEN_SESSION" \
        --sync-mode=two-way-resolved \
        --ignore-vcs \
        --ignore="/.DS_Store" 2>/dev/null; then
        tmux display-message -d 3000 "✓ ssh_shared: mutagen sync active ($MUTAGEN_SESSION)"
    else
        tmux display-message -d 5000 "⚠ ssh_shared: mutagen sync create failed"
        return 1
    fi
}

stop_shared_sync() {
    if command -v mutagen &>/dev/null; then
        mutagen sync terminate "$MUTAGEN_SESSION" 2>/dev/null || true
    fi
}

# ======================== OPTIONAL LAPTOP SSH ACCESS ======================== #
# A remote loopback listener reaches the laptop's loopback SSH service via the
# local Mutagen daemon. This is independent of file sync. It grants no login
# credentials: the remote agent still needs an SSH key authorized on the laptop.
MUTAGEN_FORWARD_SESSION=""
forward_started=0
if [[ "$laptop_ports" != disabled ]]; then
    IFS=$'\t' read -r laptop_remote_port laptop_local_port <<< "$laptop_ports"
    endpoint_name=$(printf '%s' "${user}-${host}" | tr -c 'a-zA-Z0-9_-' '-')
    MUTAGEN_FORWARD_SESSION="laptop-ssh-${endpoint_name}-${laptop_remote_port}"
fi

start_laptop_access() {
    [[ -n "$MUTAGEN_FORWARD_SESSION" ]] || return 0
    if ! command -v mutagen >/dev/null 2>&1; then
        echo "Laptop SSH access unavailable: mutagen is not installed" >&2
        return 1
    fi
    # Replace a stale managed forward left by an interrupted prior connection.
    mutagen forward terminate "$MUTAGEN_FORWARD_SESSION" 2>/dev/null || true
    if mutagen forward create \
        "${user}@${host}:tcp:127.0.0.1:${laptop_remote_port}" \
        "tcp:127.0.0.1:${laptop_local_port}" \
        --name="$MUTAGEN_FORWARD_SESSION"; then
        forward_started=1
        echo "Laptop SSH forward started: remote 127.0.0.1:$laptop_remote_port -> laptop 127.0.0.1:$laptop_local_port"
        echo "Verify Remote Login and SSH authentication separately (see LAPTOP-ACCESS.md)."
    else
        echo "Laptop SSH forward failed; continuing without laptop access" >&2
        return 1
    fi
}

cleanup_ssh_window() {
    if [[ "$forward_started" = 1 ]]; then
        mutagen forward terminate "$MUTAGEN_FORWARD_SESSION" 2>/dev/null || true
    fi
    stop_shared_sync
    # Reset SSH window markers (status colour is a format in tmux.conf; leave it)
    tmux set-option -wu @ssh_target 2>/dev/null || true
}

# Install cleanup before starting persistent resources. Reuse the existing
# file-sync lifecycle; laptop forwarding failure must not block ordinary SSH.
trap 'cleanup_ssh_window' EXIT
start_shared_sync || true
start_laptop_access || {
    tmux display-message -d 5000 "Laptop SSH access unavailable; normal SSH still works"
}

# ======================== TMUX WINDOW SETUP ======================== #

# Tag this window as an SSH target and rename it
tmux set-option -w @ssh_target "$name"
tmux rename-window "$name"

# Connect — no exec, so EXIT trap fires for cleanup
# shellcheck disable=SC2086
ssh $opts -t "${user}@${host}" '$SHELL --login -c "tmux new-session -A -s main || (echo \"Press Enter to continue\" && read)"'

# SSH exited — cleanup runs via EXIT trap

