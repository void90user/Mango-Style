#!/usr/bin/env bash

set -u

emit() {
    local status artist title text class tooltip

    status=$(playerctl status 2>/dev/null)

    case "$status" in
        Playing)
            text="󰏤"
            class="playing"
            ;;
        Paused)
            text="󰐊"
            class="paused"
            ;;
        *)
            text="󰅙"
            class="stopped"
            ;;
    esac

    if [[ "$status" == "Playing" || "$status" == "Paused" ]]; then
        artist=$(playerctl metadata artist 2>/dev/null)
        title=$(playerctl metadata title 2>/dev/null)
        if [[ -n "$artist" || -n "$title" ]]; then
            tooltip="${artist:-Unknown artist} - ${title:-Unknown title}"
        else
            tooltip="$status"
        fi
    else
        tooltip=""
    fi

    text=$(printf '%s' "$text" | sed 's/\\/\\\\/g; s/"/\\"/g')
    tooltip=$(printf '%s' "$tooltip" | sed 's/\\/\\\\/g; s/"/\\"/g')

    printf '{"text": "%s", "class": "%s", "alt": "%s", "tooltip": "%s"}\n' \
        "$text" "$class" "$class" "$tooltip"
}

emit

{
    playerctl --follow status 2>/dev/null &
    playerctl --follow metadata --format '{{status}}' 2>/dev/null &
    wait
} | while read -r _; do
    emit
done
