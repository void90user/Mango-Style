#!/usr/bin/env bash

get_device() {
    iwctl device list 2>/dev/null \
        | sed 's/\x1b\[[0-9;]*m//g' \
        | awk '/station/ {print $1; exit} NR>4 && /wlan/ {print $1; exit}'
}

DEVICE=$(get_device)
[[ -z "$DEVICE" ]] && DEVICE="wlan0"

rssi_class() {
    local r=$1
    if   (( r >= -50 )); then echo "excellent"
    elif (( r >= -60 )); then echo "good"
    elif (( r >= -70 )); then echo "fair"
    elif (( r >= -80 )); then echo "weak"
    else                      echo "poor"
    fi
}

rssi_icon() {
    local r=$1
    if   (( r >= -50 )); then echo "󰤨"
    elif (( r >= -60 )); then echo "󰤥"
    elif (( r >= -70 )); then echo "󰤢"
    elif (( r >= -80 )); then echo "󰤟"
    else                      echo "󰤯"
    fi
}

get_powered_state() {
    local powered
    powered=$(iwctl device show "$DEVICE" 2>/dev/null \
              | sed 's/\x1b\[[0-9;]*m//g' \
              | awk '/Powered/{print $NF; exit}')
    case "$powered" in
        on|On|ON)     echo "on" ;;
        off|Off|OFF) echo "off" ;;
        *)           echo "unknown" ;;
    esac
}

emit() {
    local raw powered state

    raw=$(iwctl station "$DEVICE" show 2>/dev/null \
          | sed 's/\x1b\[[0-9;]*m//g')

    state=$(echo "$raw" | awk '/State/{print $NF}')
    powered=$(get_powered_state)

    if [[ "$powered" == "off" ]]; then
        printf '{"text":"󰀝","tooltip":"Name: —\nDevice: %s\nState: Powered Off","class":"off"}\n' \
            "$DEVICE"
        return
    fi

    if [[ -z "$state" || "$state" == "disconnected" ]]; then
        printf '{"text":"󰤮","tooltip":"Name: —\nDevice: %s\nState: Disconnected","class":"disconnected"}\n' \
            "$DEVICE"
        return
    fi

    local ssid rssi ip
    ssid=$(echo "$raw" | grep -oP '(?<=Connected network\s{1,30})\S.*' | xargs)
    rssi=$(echo "$raw" | grep -oP '(?<=RSSI\s{1,30})-\d+')
    ip=$(echo   "$raw" | grep -oP '(?<=IPv4 address\s{1,30})\S+')
    rssi=${rssi:--99}

    local icon class tooltip
    icon=$(rssi_icon  "$rssi")
    class=$(rssi_class "$rssi")

    tooltip="Name: ${ssid}"
    tooltip+="\nStrength: ${rssi} dBm"
    [[ -n "$ip" ]] && tooltip+="\nIP: ${ip}"
    tooltip+="\nDevice: ${DEVICE}"

    printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
        "$icon" "$tooltip" "$class"
}

emit

if command -v inotifywait &>/dev/null; then
    inotifywait -q -m -e modify,create,delete,move \
        /var/lib/iwd/ 2>/dev/null \
        | while read -r _; do
            emit
        done
else
    emit;
fi
