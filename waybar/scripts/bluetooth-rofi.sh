#!/usr/bin/env bash

dir="$HOME/.config/rofi/bluetooth"
theme='style'

rofi_menu() { rofi -dmenu -i -no-fixed-num-lines -p "$1" -theme "${dir}/${theme}.rasi" "${@:2}"; }


notify() { command -v notify-send &>/dev/null && \
           notify-send -t 3000 -h string:x-canonical-private-synchronous:bt "$1" "$2"; }


bt_powered()  { bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; }
bt_pairable() { bluetoothctl show 2>/dev/null | grep -q "Pairable: yes"; }

all_macs() { bluetoothctl devices 2>/dev/null | awk '{print $2}'; }

device_name() {
    local mac="$1"
    bluetoothctl info "$mac" 2>/dev/null | grep -oP '(?<=Name: ).+' | head -1
}

device_connected() {
    bluetoothctl info "$1" 2>/dev/null | grep -q "Connected: yes"
}

device_paired() {
    bluetoothctl info "$1" 2>/dev/null | grep -q "Paired: yes"
}

device_type_icon() {
    local mac="$1"
    local cls
    cls=$(bluetoothctl info "$mac" 2>/dev/null | grep -oP '(?<=Icon: ).+' | head -1)
    case "$cls" in
        audio-headset|audio-headphones) echo "󰋋" ;;
        audio-card|audio-speakers)      echo "󰓃" ;;
        input-keyboard)                 echo "󰌌" ;;
        input-mouse)                    echo "󰍽" ;;
        input-gaming)                   echo "󰊗" ;;
        phone)                          echo "󰄜" ;;
        computer)                       echo "󰌢" ;;
        *)                              echo "󰂱" ;;
    esac
}


build_menu() {
    if bt_powered; then
        echo "󰂲  Turn Bluetooth Off"
    else
        echo "󰂯  Turn Bluetooth On"
        return
    fi

    if bt_pairable; then
        echo "󰂼  Pairable: On   (turn off)"
    else
        echo "󰂼  Pairable: Off  (turn on)"
    fi

    echo "󰂰  Scan for new devices…"
    echo "  Remove a device…"
    echo "─────────────────────────────────────"

    local connected=() paired=()

    while read -r mac; do
        [[ -z "$mac" ]] && continue
        local name icon marker
        name=$(device_name "$mac")
        icon=$(device_type_icon "$mac")
        name="${name:-$mac}"

        if device_connected "$mac"; then
            connected+=("connected|$mac|$icon  ✓ $name")
        elif device_paired "$mac"; then
            paired+=("paired|$mac|$icon  $name")
        fi
    done < <(all_macs)

    if (( ${#connected[@]} > 0 )); then
        for entry in "${connected[@]}"; do
            echo "${entry##*|}"
        done
        echo "─────────────────────────────────────"
    fi

    for entry in "${paired[@]}"; do
        echo "${entry##*|}"
    done
}


scan_menu() {
    notify "󰂰 Bluetooth" "Scanning for 10 seconds…"

    local before
    mapfile -t before < <(all_macs)

    bluetoothctl scan on &>/dev/null &
    local scan_pid=$!
    sleep 10
    kill "$scan_pid" 2>/dev/null
    bluetoothctl scan off &>/dev/null

    local new_entries=()
    while read -r mac; do

        local known=0
        for b in "${before[@]}"; do [[ "$b" == "$mac" ]] && known=1 && break; done
        (( known )) && continue

        local name icon
        name=$(device_name "$mac")
        icon=$(device_type_icon "$mac")
        new_entries+=("$mac|$icon  ${name:-$mac}")
    done < <(all_macs)

    if (( ${#new_entries[@]} == 0 )); then
        notify "󰂰 Bluetooth" "No new devices found"
        exec "$0"
    fi

    local choice
    choice=$(for e in "${new_entries[@]}"; do echo "${e##*|}"; done \
             | rofi_menu "󰂰 Connect to…")
    [[ -z "$choice" ]] && exec "$0"

    local target_mac=""
    for e in "${new_entries[@]}"; do
        local mac="${e%%|*}" label="${e##*|}"

        local name_part
        name_part=$(echo "$label" | sed 's/^[^ ]* //')
        if [[ "$choice" == *"$name_part"* ]]; then
            target_mac="$mac"
            break
        fi
    done

    [[ -z "$target_mac" ]] && exec "$0"

    notify "󰂱 Bluetooth" "Pairing with ${choice}…"
    bluetoothctl pair    "$target_mac" &>/dev/null
    bluetoothctl connect "$target_mac" &>/dev/null
    sleep 3

    if device_connected "$target_mac"; then
        notify "󰂱 Bluetooth" "Connected to ${choice}"
    else
        notify "󰂲 Bluetooth" "Could not connect to ${choice}"
    fi
    exec "$0"
}


remove_menu() {
    local entries=()
    while read -r mac; do
        [[ -z "$mac" ]] && continue
        local name icon
        name=$(device_name "$mac")
        icon=$(device_type_icon "$mac")
        entries+=("$mac|$icon  ${name:-$mac}")
    done < <(all_macs)

    (( ${#entries[@]} == 0 )) && { notify "󰂲 Bluetooth" "No paired devices"; exec "$0"; }

    local choice
    choice=$(for e in "${entries[@]}"; do echo "${e##*|}"; done \
             | rofi_menu " Remove device")
    [[ -z "$choice" ]] && exec "$0"

    local confirm
    confirm=$(printf "Yes, remove\nCancel" \
              | rofi_menu "Remove \"${choice}\"?")
    if [[ "$confirm" == "Yes, remove" ]]; then
        local target_mac=""
        for e in "${entries[@]}"; do
            [[ "${e##*|}" == "$choice" ]] && target_mac="${e%%|*}" && break
        done
        [[ -n "$target_mac" ]] && bluetoothctl remove "$target_mac" &>/dev/null
        notify " Bluetooth" "Removed ${choice}"
    fi
    exec "$0"
}


toggle_device() {
    local choice="$1"

    local name
    name=$(echo "$choice" | sed 's/^[^ ]* //' | sed 's/^✓ //' | xargs)

    local target_mac=""
    while read -r mac; do
        local dname
        dname=$(device_name "$mac")
        [[ "${dname:-$mac}" == "$name" ]] && target_mac="$mac" && break
    done < <(all_macs)

    [[ -z "$target_mac" ]] && exec "$0"

    if device_connected "$target_mac"; then
        notify "󰂲 Bluetooth" "Disconnecting from ${name}…"
        bluetoothctl disconnect "$target_mac" &>/dev/null
        notify "󰂲 Bluetooth" "Disconnected from ${name}"
    else
        notify "󰂱 Bluetooth" "Connecting to ${name}…"
        bluetoothctl connect "$target_mac" &>/dev/null
        sleep 3
        if device_connected "$target_mac"; then
            notify "󰂱 Bluetooth" "Connected to ${name}"
        else
            notify "󰂲 Bluetooth" "Could not connect to ${name}"
        fi
    fi
    exec "$0"
}


while true; do
    choice=$(build_menu | rofi_menu "󰂯 Bluetooth")
    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        "─"*)                   exec "$0" ;;
        *"Turn Bluetooth Off"*) bluetoothctl power off    &>/dev/null; exit 0    ;;
        *"Turn Bluetooth On"*)  bluetoothctl power on     &>/dev/null; exec "$0" ;;
        *"Pairable: On"*)       bluetoothctl pairable off &>/dev/null; exec "$0" ;;
        *"Pairable: Off"*)      bluetoothctl pairable on  &>/dev/null; exec "$0" ;;
        *"Scan for new"*)       scan_menu ;;
        *"Remove a device"*)    remove_menu ;;
        *)                      toggle_device "$choice" ;;
    esac
done
