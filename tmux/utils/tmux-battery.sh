#!/usr/bin/env bash
# tmux-battery.sh - Battery status for tmux status line
# Converted from wezterm.lua format_battery_status()
# Usage: Add to tmux.conf:  set -g status-right '#(~/tmux-battery.sh)'

# Nerd Font icons (portable octal UTF-8 — works on bash 3.2+)
ICON_FULL=$(printf '\357\211\200')          # U+F240 fa_battery_full
ICON_THREE_QUARTERS=$(printf '\357\211\201') # U+F241 fa_battery_three_quarters
ICON_HALF=$(printf '\357\211\202')          # U+F242 fa_battery_half
ICON_QUARTER=$(printf '\357\211\203')       # U+F243 fa_battery_quarter
ICON_EMPTY=$(printf '\357\211\204')         # U+F244 fa_battery_empty
ICON_ARROW_UP=$(printf '\357\200\275')      # U+F03D oct_arrow_up
ICON_ARROW_DOWN=$(printf '\357\200\277')    # U+F03F oct_arrow_down

get_battery_icon() {
    local charge=$1
    if (( charge > 90 )); then
        echo "$ICON_FULL"
    elif (( charge > 66 )); then
        echo "$ICON_THREE_QUARTERS"
    elif (( charge > 45 )); then
        echo "$ICON_HALF"
    elif (( charge > 10 )); then
        echo "$ICON_QUARTER"
    else
        echo "$ICON_EMPTY"
    fi
}

format_time() {
    local minutes=$1
    local state=$2
    if [[ -z "$minutes" || "$minutes" == "0" ]]; then
        return
    fi
    local hours
    hours=$(awk "BEGIN {printf \"%.1f\", $minutes / 60}")
    if [[ "$state" == "charging" ]]; then
        printf " %s%sH" "$ICON_ARROW_UP" "$hours"
    else
        printf " %s%sH" "$ICON_ARROW_DOWN" "$hours"
    fi
}

# --- macOS (pmset) ---
battery_macos() {
    local pmset_output
    pmset_output=$(pmset -g batt 2>/dev/null) || return 1

    # Parse: " -InternalBattery-0 (id=...)  85%; charging; 1:23 remaining ..."
    local line
    line=$(echo "$pmset_output" | grep -E "InternalBattery")
    [[ -z "$line" ]] && return 1

    local charge state time_remaining_min

    charge=$(echo "$line" | grep -oE '[0-9]+%' | tr -d '%')
    [[ -z "$charge" ]] && return 1

    if echo "$line" | grep -qi "charging"; then
        state="charging"
    elif echo "$line" | grep -qi "discharging"; then
        state="discharging"
    else
        state="full"
    fi

    # Time remaining in H:MM format
    local time_str
    time_str=$(echo "$line" | grep -oE '[0-9]+:[0-9]+' | head -1)
    if [[ -n "$time_str" ]]; then
        local h m
        h=$(echo "$time_str" | cut -d: -f1)
        m=$(echo "$time_str" | cut -d: -f2)
        time_remaining_min=$(( h * 60 + 10#$m ))
    fi

    local icon
    icon=$(get_battery_icon "$charge")
    local time_fmt
    time_fmt=$(format_time "$time_remaining_min" "$state")

    printf "%s %d%%%s" "$icon" "$charge" "$time_fmt"
}

# --- Linux (sysfs) ---
battery_linux() {
    local bat_path
    local found=0

    for bat_path in /sys/class/power_supply/BAT*; do
        [[ -d "$bat_path" ]] || continue
        found=1

        local charge state time_remaining_min

        # Read charge level
        if [[ -f "$bat_path/capacity" ]]; then
            charge=$(cat "$bat_path/capacity")
        else
            continue
        fi

        # Read state
        if [[ -f "$bat_path/status" ]]; then
            local raw_state
            raw_state=$(cat "$bat_path/status")
            case "$raw_state" in
                Charging) state="charging" ;;
                Discharging) state="discharging" ;;
                *) state="full" ;;
            esac
        fi

        # Estimate time remaining from energy/power
        if [[ -f "$bat_path/power_now" && -f "$bat_path/energy_now" ]]; then
            local power_now energy_now energy_full
            power_now=$(cat "$bat_path/power_now")
            energy_now=$(cat "$bat_path/energy_now")

            if [[ "$power_now" -gt 0 ]]; then
                if [[ "$state" == "charging" && -f "$bat_path/energy_full" ]]; then
                    energy_full=$(cat "$bat_path/energy_full")
                    time_remaining_min=$(awk "BEGIN {printf \"%d\", ($energy_full - $energy_now) / $power_now * 60}")
                elif [[ "$state" == "discharging" ]]; then
                    time_remaining_min=$(awk "BEGIN {printf \"%d\", $energy_now / $power_now * 60}")
                fi
            fi
        # Fallback: charge_now / current_now (older kernels)
        elif [[ -f "$bat_path/current_now" && -f "$bat_path/charge_now" ]]; then
            local current_now charge_now charge_full
            current_now=$(cat "$bat_path/current_now")
            charge_now=$(cat "$bat_path/charge_now")

            if [[ "$current_now" -gt 0 ]]; then
                if [[ "$state" == "charging" && -f "$bat_path/charge_full" ]]; then
                    charge_full=$(cat "$bat_path/charge_full")
                    time_remaining_min=$(awk "BEGIN {printf \"%d\", ($charge_full - $charge_now) / $current_now * 60}")
                elif [[ "$state" == "discharging" ]]; then
                    time_remaining_min=$(awk "BEGIN {printf \"%d\", $charge_now / $current_now * 60}")
                fi
            fi
        fi

        local icon
        icon=$(get_battery_icon "$charge")
        local time_fmt
        time_fmt=$(format_time "$time_remaining_min" "$state")

        printf "%s %d%%%s" "$icon" "$charge" "$time_fmt"
    done

    [[ "$found" -eq 0 ]] && return 1
}

# --- Main ---
case "$(uname -s)" in
    Darwin) battery_macos ;;
    Linux)  battery_linux ;;
    *)      echo "?" ;;
esac
