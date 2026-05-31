#!/usr/bin/env bash

dir="$HOME/.config/rofi/powermenu"
theme='style'

uptime="`uptime -p | sed -e 's/up //g'`"
host=`hostnamectl | awk '/Static hostname/ {print $NF}'`

reboot=' Reboot'
suspend='󰒲 Suspend '
hibernate='󰒲 Hibernate 󰋊'
logout=' Logout'
shutdown=' Shutdown'
yes=' Yes'
no=' No'

rofi_cmd() {
	rofi -dmenu \
		-p "$host" \
		-mesg "Uptime: $uptime" \
		-theme ${dir}/${theme}.rasi
}

confirm_cmd() {
	rofi -theme-str 'window {location: center; anchor: center; fullscreen: false; width: 250px;}' \
		-theme-str 'mainbox {children: [ "message", "listview" ];}' \
		-theme-str 'listview {columns: 2; lines: 1;}' \
		-theme-str 'element-text {horizontal-align: 0.5;}' \
		-theme-str 'textbox {horizontal-align: 0.5;}' \
		-dmenu \
		-p 'Confirmation' \
		-mesg 'Are you Sure?' \
		-theme ${dir}/${theme}.rasi
}

confirm_exit() {
	echo -e "$yes\n$no" | confirm_cmd
}

run_rofi() {
	echo -e "$shutdown\n$reboot\n$suspend\n$hibernate\n$logout\n" | rofi_cmd
}


pre_suspend() {
    command -v playerctl &>/dev/null && playerctl pause 2>/dev/null
}

run_cmd() {
	selected="$(confirm_exit)"
	if [[ "$selected" == "$yes" ]]; then
		if [[ $1 == '--shutdown' ]]; then
			systemctl poweroff
		elif [[ $1 == '--reboot' ]]; then
			systemctl reboot
		elif [[ $1 == '--suspend' ]]; then
			pre_suspend
			systemctl suspend
		elif [[ $1 == '--hibernate' ]]; then
			pre_suspend
			systemctl hibernate
		elif [[ $1 == '--logout' ]]; then
			mmsg quit
		fi
	else
		exit 0
	fi
}


chosen="$(run_rofi)"
case ${chosen} in
    $shutdown)
		run_cmd --shutdown
        ;;
    $reboot)
		run_cmd --reboot
        ;;
	$hibernate)
		run_cmd --hibernate
		;;
    $suspend)
		run_cmd --suspend
        ;;
    $logout)
		run_cmd --logout
        ;;
esac
