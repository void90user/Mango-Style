#!/usr/bin/bash

export MANGO_INSTANCE_SIGNATURE=$(ls /run/user/"$(id -u)"/mango-*.sock 2>/dev/null | head -1)

ROFI_THEME="$HOME/.config/rofi/applets/layout-switch/style.rasi"

declare -a LAYOUTS=(
    "tile|Tile"
    "fair|Fair"
    "grid|Grid"
    "deck|Deck"
    "monocle|Monocle"
    "dwindle|Dwindle"
    "scroller|Scroller"
    "right_tile|Right Tile"
    "center_tile|Center Tile"
    "vertical_tile|Vert. Tile"
    "vertical_grid|Vert. Grid"
    "vertical_deck|Vert. Deck"
    "vertical_fair|Vert. Fair"
    "vertical_scroller|Vert. Scroller"
)

get_monitor_names() {
    local raw="$1"
    echo "$raw" | grep -oP '(?<="name":")[^"]+'
}

get_monitor_layout() {
    local raw="$1" mon="$2"
    echo "$raw" \
        | grep -oP "\"name\":\"${mon}\".*?(?=\"name\":\"|\$)" \
        | grep -oP '(?<="layout_symbol":")[^"]+' \
        | head -1
}

RAW_JSON=$(mmsg get all-monitors 2>/dev/null)
if [ -z "$RAW_JSON" ]; then
    notify-send "MangoWM" "Could not connect to mango (mmsg get all-monitors returned nothing)" 2>/dev/null
    exit 1
fi

MONITOR_NAMES=$(get_monitor_names "$RAW_JSON")
if [ -z "$MONITOR_NAMES" ]; then
    notify-send "MangoWM" "No monitors found" 2>/dev/null
    exit 1
fi

MON_MENU="󰍺  All Monitors"
while IFS= read -r mon; do
    sym=$(get_monitor_layout "$RAW_JSON" "$mon")
    if [ -n "$sym" ]; then
        MON_MENU+=$'\n'"󰍹  $mon  [$sym]"
    else
        MON_MENU+=$'\n'"󰍹  $mon"
    fi
done <<< "$MONITOR_NAMES"

SELECTED_MON=$(printf '%s' "$MON_MENU" | rofi \
    -theme "$ROFI_THEME" \
    -dmenu \
    -i \
    -p "󰍺 Monitor")

[ -z "$SELECTED_MON" ] && exit 0

if [[ "$SELECTED_MON" == *"All Monitors"* ]]; then
    TARGET="ALL"
else
    TARGET=$(echo "$SELECTED_MON" | awk '{print $2}' | sed 's/\[.*//;s/[[:space:]]*//')
fi

LAYOUT_MENU=""
for entry in "${LAYOUTS[@]}"; do
    IFS='|' read -r name label <<< "$entry"
    LAYOUT_MENU+="$label  [$name]"$'\n'
done

SELECTED_LAYOUT=$(printf '%s' "$LAYOUT_MENU" | rofi \
    -theme "$ROFI_THEME" \
    -dmenu \
    -i \
    -p "󰕰 Layout")

[ -z "$SELECTED_LAYOUT" ] && exit 0

LAYOUT_NAME=$(echo "$SELECTED_LAYOUT" | grep -oP '(?<=\[)[a-z_]+(?=\])')
if [ -z "$LAYOUT_NAME" ]; then
    notify-send "MangoWM" "Could not parse layout from: $SELECTED_LAYOUT" 2>/dev/null
    exit 1
fi

apply_to_monitor() {
    local mon="$1"
    mmsg dispatch "focusmon,${mon}" 2>/dev/null
    mmsg dispatch "setlayout,${LAYOUT_NAME}" 2>/dev/null
}

if [ "$TARGET" = "ALL" ]; then
    while IFS= read -r mon; do
        apply_to_monitor "$mon"
    done <<< "$MONITOR_NAMES"
else
    apply_to_monitor "$TARGET"
fi

pkill -SIGRTMIN+8 waybar 2>/dev/null

exit 0
