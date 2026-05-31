#!/usr/bin/env bash

dir="$HOME/.config/rofi/wifi"
theme='style'

rofi_menu() { rofi -dmenu -i -no-fixed-num-lines -p "$1" -theme "${dir}/${theme}.rasi" "${@:2}"; }


strip_ansi() { sed 's/\x1b\[[0-9;]*m//g; s/\x1b\[?[0-9]*[hl]//g'; }

notify() { command -v notify-send &>/dev/null && \
           notify-send -t 3000 -h string:x-canonical-private-synchronous:wifi "$1" "$2"; }

get_device() {
    iwctl device list 2>/dev/null | strip_ansi \
        | awk '/station/{print $1; exit} NR>4 && /wlan/{print $1; exit}'
}

DEVICE=$(get_device)
[[ -z "$DEVICE" ]] && DEVICE="wlan0"


stars_to_icon() {
    case "$1" in
        "****") echo "󰤨" ;;
        "***")  echo "󰤥" ;;
        "**")   echo "󰤢" ;;
        "*")    echo "󰤟" ;;
        *)      echo "󰤯" ;;
    esac
}


get_connected_ssid() {
    iwctl station "$DEVICE" show 2>/dev/null | strip_ansi \
        | awk '/Connected network/{$1=$2=""; print $0}' | xargs
}

get_state() {
    iwctl station "$DEVICE" show 2>/dev/null | strip_ansi \
        | awk '/[[:space:]]State[[:space:]]/{print $NF}'
}


get_known_networks() {
    iwctl known-networks list 2>/dev/null | strip_ansi \
        | awk 'NR>4 && /psk|open|8021x/ {print $1}'
}


build_menu() {
    local connected_ssid state
    connected_ssid=$(get_connected_ssid)
    state=$(get_state)

    echo "  Rescan networks"
    echo "  Forget a network…"
    echo "─────────────────────────────────────"

    iwctl station "$DEVICE" scan &>/dev/null

    iwctl station "$DEVICE" get-networks 2>/dev/null | strip_ansi \
        | awk 'NR>4 && /psk|open|8021x/ {
            # Reconstruct: active flag is col1 if ">", else blank
            active = ($1 == ">") ? 1 : 0
            if (active) { $1=""; }     # remove > from field list
            # Last field is signal stars, second-to-last is security
            stars  = $NF
            sec    = $(NF-1)
            # SSID is everything between start and sec field
            n = NF - 2
            ssid = ""
            for (i=1; i<=n; i++) ssid = ssid (ssid=="" ? "" : " ") $i
            gsub(/^ +| +$/, "", ssid)
            print active "|" ssid "|" sec "|" stars
        }' \
        | sort -t'|' -k1 -rn \
        | while IFS='|' read -r active ssid sec stars; do
            local icon lock known_mark active_mark
            icon=$(stars_to_icon "$stars")
            [[ "$sec" != "open" ]] && lock="󰌾 " || lock=""

            if get_known_networks | grep -qxF "$ssid" 2>/dev/null; then
                known_mark="󰆓 "
            fi

            [[ "$active" == "1" ]] && active_mark=" " || active_mark=""

            printf '%s %s%s%s%s\n' \
                "$icon" "$active_mark" "$known_mark" "$lock" "$ssid"

            known_mark=""
        done
}


connect() {
    local ssid="$1"

    if get_known_networks | grep -qxF "$ssid" 2>/dev/null; then
        notify "󰤨 WiFi" "Connecting to $ssid…"
        iwctl station "$DEVICE" connect "$ssid" &>/dev/null
        wait_for_connection "$ssid"
        return
    fi

    local sec
    sec=$(iwctl station "$DEVICE" get-networks 2>/dev/null | strip_ansi \
          | awk -v target="$ssid" '
              $0 ~ target {
                  print $(NF-1)
                  exit
              }')

    if [[ "$sec" == "open" ]]; then
        notify "󰤨 WiFi" "Connecting to $ssid…"
        iwctl station "$DEVICE" connect "$ssid" &>/dev/null
    else

        local pass
        pass=$(rofi -dmenu -i -no-fixed-num-lines \
               -p "󰌾 Passphrase for \"$ssid\"" \
               -password \
               -theme "${dir}/${theme}.rasi" \
               -theme-str 'window { width: 320px; }')
        [[ -z "$pass" ]] && return

        notify "󰤨 WiFi" "Connecting to $ssid…"
        iwctl --passphrase "$pass" station "$DEVICE" connect "$ssid" &>/dev/null
    fi

    wait_for_connection "$ssid"
}

wait_for_connection() {
    local ssid="$1" deadline=$(( SECONDS + 12 ))
    while (( SECONDS < deadline )); do
        sleep 1
        local current
        current=$(get_connected_ssid)
        if [[ "$current" == "$ssid" ]]; then
            notify "󰤨 WiFi" "Connected to $ssid"
            return
        fi
    done
    notify "󰤯 WiFi" "Could not connect to $ssid"
}


forget_menu() {
    local known
    known=$(get_known_networks | rofi_menu "󰛌 Forget which network?")
    [[ -z "$known" ]] && exec "$0"

    local confirm
    confirm=$(printf "Yes, forget \"%s\"\nCancel" "$known" \
              | rofi_menu "Really forget \"$known\"?")
    if [[ "$confirm" == "Yes, forget \"$known\"" ]]; then
        iwctl known-networks "$known" forget &>/dev/null
        notify " WiFi" "Forgot \"$known\""
    fi
    exec "$0"
}


while true; do
    choice=$(build_menu | rofi_menu "󰤨 WiFi  ($DEVICE)")
    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        "─"*)                exec "$0" ;;

        *"Rescan"*)
            iwctl station "$DEVICE" scan &>/dev/null
            sleep 2
            exec "$0" ;;

        *"Forget a network"*)
            forget_menu ;;

        *)
            ssid=$(echo "$choice" \
                   | sed 's/^[^ ]* //'        \
                   | sed 's/^[✓★󰌾 ]*//'    \
                   | sed 's/  \[.*\]$//'       \
                   | xargs)
            [[ -n "$ssid" ]] && connect "$ssid"
            exec "$0" ;;
    esac
done
