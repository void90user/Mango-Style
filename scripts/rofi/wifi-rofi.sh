#!/usr/bin/env bash

dir="$HOME/.config/rofi/applets/wifi"
theme='style'

rofi_menu() { rofi -dmenu -i -no-fixed-num-lines -p "$1" -theme "${dir}/${theme}.rasi" "${@:2}"; }

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g; s/\x1b\[?[0-9]*[hl]//g'; }

notify() { command -v notify-send &>/dev/null && \
           notify-send -t 3000 -h string:x-canonical-private-synchronous:wifi "$1" "$2"; }

get_devices() {
    iwctl device list 2>/dev/null | strip_ansi \
        | awk '/station/{print $1}' | sort -u
}

mapfile -t DEVICES < <(get_devices)
[[ ${#DEVICES[@]} -eq 0 ]] && DEVICES=("wlan0")
DEVICE="${DEVICES[0]}"

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
    local dev="${1:-$DEVICE}"
    iwctl station "$dev" show 2>/dev/null | strip_ansi \
        | awk '/Connected network/{for(i=3;i<=NF;i++)
               printf "%s%s",$i,(i<NF?" ":""); print ""}' | xargs
}

get_state() {
    local dev="${1:-$DEVICE}"
    iwctl station "$dev" show 2>/dev/null | strip_ansi \
        | awk '/[[:space:]]State[[:space:]]/{print $NF}'
}

get_known_networks() {
    iwctl known-networks list 2>/dev/null | strip_ansi \
        | awk 'NR>4 && /psk|open|8021x/ {print $1}'
}

MENU_LINES=()
MENU_SSIDS=()

build_menu() {
    MENU_LINES=()
    MENU_SSIDS=()

    local dev conn
    declare -A connected_map
    for dev in "${DEVICES[@]}"; do
        conn=$(get_connected_ssid "$dev")
        [[ -n "$conn" ]] && connected_map["$conn"]=1
    done

    MENU_LINES+=("󰑐  Rescan networks");          MENU_SSIDS+=("__rescan__")
    MENU_LINES+=("󰚹  Disconnect…");               MENU_SSIDS+=("__disconnect__")
    MENU_LINES+=("󰚿  Forget a network…");          MENU_SSIDS+=("__forget__")
    MENU_LINES+=("─────────────────────────────────────"); MENU_SSIDS+=("__separator__")

    iwctl station "$DEVICE" scan &>/dev/null

    local menu_data
    menu_data=$(iwctl station "$DEVICE" get-networks 2>/dev/null | strip_ansi \
        | awk 'NR>4 && /psk|open|8021x/ {
            active = ($1 == ">") ? 1 : 0
            if (active) { $1="" }
            stars = $NF
            sec = $(NF-1)
            n = NF - 2
            ssid = ""
            for (i=1; i<=n; i++) ssid = ssid (ssid=="" ? "" : " ") $i
            gsub(/^ +| +$/, "", ssid)
            print active "|" ssid "|" sec "|" stars
        }' | sort -t'|' -k1 -rn)

    local known
    known=$(get_known_networks)

    local active ssid sec stars icon lock known_mark active_mark line
    while IFS='|' read -r active ssid sec stars; do
        [[ -z "$ssid" ]] && continue

        icon=$(stars_to_icon "$stars")
        [[ "$sec" != "open" ]] && lock="󰌾 " || lock=""

        known_mark=""
        if grep -qxF "$ssid" <<<"$known" 2>/dev/null; then
            known_mark="󰆓 "
        fi

        if [[ -n "${connected_map[$ssid]+x}" ]]; then
            active_mark="✓ "
        else
            active_mark=""
        fi

        line=$(printf '%s %s%s%s%s' "$icon" "$active_mark" "$known_mark" "$lock" "$ssid")
        MENU_LINES+=("$line")
        MENU_SSIDS+=("$ssid")
    done <<<"$menu_data"
}

pick_device() {
    local picked
    picked=$(printf '%s\n' "${DEVICES[@]}" | rofi_menu "󰒍 Connect via which device?")
    [[ -z "$picked" ]] && return 1
    printf '%s' "$picked"
}

connect() {
    local ssid="$1"
    local dev="${2:-$DEVICE}"
    local d
    for d in "${DEVICES[@]}"; do
        local c
        c=$(get_connected_ssid "$d")
        if [[ "$c" == "$ssid" ]]; then
            notify "󰤨 WiFi" "Already connected to $ssid on $d"
            return 0
        fi
    done

    if get_known_networks | grep -qxF "$ssid" 2>/dev/null; then
        notify "󰤨 WiFi" "Connecting to $ssid via $dev…"
        iwctl station "$dev" connect "$ssid" &>/dev/null
        wait_for_connection "$ssid" "$dev"
        return
    fi

    local sec
    sec=$(iwctl station "$dev" get-networks 2>/dev/null | strip_ansi \
          | awk -v target="$ssid" '
              $0 ~ target {
                  print $(NF-1)
                  exit
              }')

    if [[ "$sec" == "open" ]]; then
        notify "󰤨 WiFi" "Connecting to $ssid via $dev…"
        iwctl station "$dev" connect "$ssid" &>/dev/null
    else
        local pass
        pass=$(rofi -dmenu -i -no-fixed-num-lines \
               -p "󰌾 Passphrase for \"$ssid\"" \
               -password \
               -theme "${dir}/${theme}.rasi" \
               -theme-str 'window { width: 320px; }')
        [[ -z "$pass" ]] && return

        notify "󰤨 WiFi" "Connecting to $ssid via $dev…"
        iwctl --passphrase "$pass" station "$dev" connect "$ssid" &>/dev/null
    fi

    wait_for_connection "$ssid" "$dev"
}

wait_for_connection() {
    local ssid="$1" dev="${2:-$DEVICE}"
    local deadline=$(( SECONDS + 12 ))
    while (( SECONDS < deadline )); do
        sleep 1
        local current
        current=$(get_connected_ssid "$dev")
        if [[ "$current" == "$ssid" ]]; then
            notify "󰤨 WiFi" "Connected to $ssid via $dev"
            return
        fi
    done
    notify "󰤯 WiFi" "Could not connect to $ssid"
}

disconnect_menu() {
    local dev picked_ssid
    local disconnect_lines=()
    declare -A dev_of_ssid
    local d ssid
    for d in "${DEVICES[@]}"; do
        ssid=$(get_connected_ssid "$d")
        if [[ -n "$ssid" ]]; then
            disconnect_lines+=("$ssid  (on $d)")
            dev_of_ssid["$ssid"]="$d"
        fi
    done

    if [[ ${#disconnect_lines[@]} -eq 0 ]]; then
        notify "󰤯 WiFi" "Not connected to any network"
        return
    fi

    picked_ssid=$(printf '%s\n' "${disconnect_lines[@]}" \
                  | rofi_menu "󰚹 Disconnect which?" \
                  | sed 's/  (on .*)$//')

    [[ -z "$picked_ssid" ]] && return
    iwctl station "${dev_of_ssid[$picked_ssid]}" disconnect &>/dev/null
    notify "󰤨 WiFi" "Disconnected from $picked_ssid"
}

forget_menu() {
    local known
    known=$(get_known_networks | rofi_menu "󰚿 Forget which network?")
    [[ -z "$known" ]] && return

    local confirm
    confirm=$(printf "Yes, forget \"%s\"\nCancel" "$known" \
              | rofi_menu "Really forget \"$known\"?")
    if [[ "$confirm" == "Yes, forget \"$known\"" ]]; then
        iwctl known-networks "$known" forget &>/dev/null
        notify "󰤨 WiFi" "Forgot \"$known\""
    fi
}

while true; do
    build_menu
    choice_idx=$(printf '%s\n' "${MENU_LINES[@]}" \
                 | rofi -dmenu -i -no-fixed-num-lines \
                       -p "󰤨 WiFi  (${DEVICES[*]})" \
                       -format i \
                       -theme "${dir}/${theme}.rasi")

    [[ -z "$choice_idx" ]] && exit 0

    ssid="${MENU_SSIDS[$choice_idx]}"

    case "$ssid" in
        __separator__)
            exec "$0" ;;

        __rescan__)
            iwctl station "$DEVICE" scan &>/dev/null
            sleep 2
            exec "$0" ;;

        __disconnect__)
            disconnect_menu
            exec "$0" ;;

        __forget__)
            forget_menu
            exec "$0" ;;

        *)
            if [[ ${#DEVICES[@]} -gt 1 ]]; then
                chosen_dev=$(pick_device) || exec "$0"
            else
                chosen_dev="$DEVICE"
            fi

            [[ -n "$ssid" ]] && connect "$ssid" "$chosen_dev"
            exec "$0" ;;
    esac
done
