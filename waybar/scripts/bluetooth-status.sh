#!/usr/bin/env bash

emit() {
    local powered
    powered=$(bluetoothctl show 2>/dev/null | grep -oP '(?<=Powered: )\S+')

    if [[ "$powered" != "yes" ]]; then
        printf '{"text":"󰂲","tooltip":"Bluetooth off","class":"off"}'
        return
    fi

    local connected_lines
    connected_lines=$(bluetoothctl devices Connected 2>/dev/null)
    local count
    count=$(echo "$connected_lines" | grep -c 'Device' 2>/dev/null | echo 0)

    local icon class tooltip
    if (( count < 1 )); then
        icon="󰂯"; class="on"
        tooltip="Bluetooth on \nNo devices connected"
    else
        icon="󰂱"; class="connected"
        tooltip="Bluetooth on \nConnected (${count}):"
        while read -r _ _ name; do
            [[ -z "$name" ]] && continue
            tooltip+="  󰂱 ${name}"
        done <<< "$connected_lines"
    fi

    printf '{"text":"%s","tooltip":"%s","class":"%s"}' \
        "$icon" "$tooltip" "$class"
}

emit
