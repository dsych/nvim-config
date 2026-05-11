#!/usr/bin/env bash -e
set -euo pipefail

HOSTS_FILE="${TMUX_SSH_HOSTS:-$HOME/.config/tmux/utils/hosts.json}"
SHARED_DIR="${TMUX_SSH_SHARED:-$HOME/ssh_shared}"

if [[ ! -f "$HOSTS_FILE" ]]; then
    echo "No hosts file found at $HOSTS_FILE" >&2
    exit 1
fi

# Build display lines: "name | user@host"
entries=$(jq -r '.[] | "\(.name) | \(.username)@\(.remote_address)"' "$HOSTS_FILE")

# fzf picker
selected=$(echo "$entries" | fzf \
    --prompt="SSH Target> " \
    --header="prefix+R | SSH Connect" \
    --height=100% \
    --reverse \
    --border \
    --no-info)

# Cancelled — exit closes this temporary window
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
        '.[] | select(.name == $n) | "\(.username) \(.remote_address) \(.additional_ssh_options)"' \
        "$HOSTS_FILE"
)

# Sync tmux config directory to remote before connecting
echo "Syncing tmux config to ${host}..."
# shellcheck disable=SC2086
ssh $opts "${user}@${host}" "mkdir -p ~/.config/tmux" 2>/dev/null
# shellcheck disable=SC2086
rsync -aq -e "ssh $opts" "$HOME/.config/tmux/" "${user}@${host}:~/.config/tmux/" || echo "Warning: failed to sync tmux config"

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

cleanup_ssh_window() {
    stop_shared_sync
    # Reset SSH window markers and status style
    tmux set-option -wu @ssh_target 2>/dev/null || true
    tmux set-option -gu status-style 2>/dev/null || true
}

# Start sync (non-blocking — mutagen runs as a daemon)
start_shared_sync || true

# Ensure full cleanup when this window closes or SSH exits
trap 'cleanup_ssh_window' EXIT

# ======================== TMUX WINDOW SETUP ======================== #

# Tag this window as an SSH target and rename it
tmux set-option -w @ssh_target "$name"
tmux rename-window "$name"
tmux set-option -g status-style 'bg=default,fg=default'

# Connect — no exec, so EXIT trap fires for cleanup
# shellcheck disable=SC2086
ssh $opts -t "${user}@${host}" '$SHELL --login -c "tmux new-session -A -s main || (echo \"Press Enter to continue\" && read)"'

# SSH exited — cleanup runs via EXIT trap

