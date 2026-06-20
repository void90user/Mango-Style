#!/usr/bin/env bash
#
# Usage:
#   wallpaper-rotate.sh [OPTIONS] [FILE|DIR ...]
#
# Options:
#   -i SECONDS   Interval between wallpaper changes (default: 300)
#   -m MODE      swaybg scaling mode: stretch, fill, fit, center, tile, solid_color
#                (default: fill)
#   -h           Show this help message
#
# Examples:
#   wallpaper-rotate.sh ~/Pictures/wallpapers
#   wallpaper-rotate.sh -i 60 ~/Pictures/wallpapers
#   wallpaper-rotate.sh -i 30 -m fit ~/wallpaper1.jpg ~/wallpaper2.png
#   wallpaper-rotate.sh -i 120 ~/wallpapers/ ~/extra/bg.jpg
#
# If no folder/image is supplied the script will try to use current directory.

set -euo pipefail


INTERVAL=300
MODE="fill"
SUPPORTED_EXT="jpg|jpeg|png|gif|webp|bmp|tiff"


usage() {
    sed -n '2,16p' "$0" | sed 's/^# \?//'
    exit "${1:-0}"
}

die() { echo "ERROR: $*" >&2; exit 1; }


while getopts ":i:m:h" opt; do
    case $opt in
        i) INTERVAL="$OPTARG" ;;
        m) MODE="$OPTARG" ;;
        h) usage 0 ;;
        :) die "Option -$OPTARG requires an argument." ;;
        \?) die "Unknown option: -$OPTARG" ;;
    esac
done
shift $((OPTIND - 1))


command -v swaybg  &>/dev/null || die "'swaybg' not found."
command -v shuf    &>/dev/null || die "'shuf' not found (part of GNU coreutils)."

[[ "$INTERVAL" =~ ^[0-9]+$ && "$INTERVAL" -gt 0 ]] \
    || die "Interval must be a positive integer (got: '$INTERVAL')."

valid_modes="stretch fill fit center tile solid_color"
[[ " $valid_modes " == *" $MODE "* ]] \
    || die "Invalid mode '$MODE'. Choose from: $valid_modes"


mapfile -t WALLPAPERS < <(
    if [[ $# -eq 0 ]]; then
        find . -maxdepth 1 -type f | grep -iE "\.($SUPPORTED_EXT)$"
    else
        for arg in "$@"; do
            if [[ -d "$arg" ]]; then
                find "$arg" -type f | grep -iE "\.($SUPPORTED_EXT)$"
            elif [[ -f "$arg" ]]; then
                echo "$arg"
            else
                echo "WARNING: '$arg' is not a file or directory, skipping." >&2
            fi
        done
    fi | sort -u
)

[[ ${#WALLPAPERS[@]} -gt 0 ]] \
    || die "No supported image files found. Supported: ${SUPPORTED_EXT//|/, }"


if [[ -z "${MANGO_INSTANCE_SIGNATURE:-}" ]]; then
    export MANGO_INSTANCE_SIGNATURE
    MANGO_INSTANCE_SIGNATURE=$(ls /run/user/$(id -u)/mango-*.sock 2>/dev/null | head -1 || true)
fi


SWAYBG_PID=""
WATCHDOG_PID=""

_orig_cleanup() {
    [[ -n "$SWAYBG_PID" ]]   && kill "$SWAYBG_PID"   2>/dev/null || true
    [[ -n "$WATCHDOG_PID" ]] && kill "$WATCHDOG_PID" 2>/dev/null || true
    exit 0
}
trap _orig_cleanup INT TERM


wm_watchdog() {
    if ! command -v mmsg &>/dev/null; then
        echo "WARNING: 'mmsg' not found; WM watchdog inactive." >&2
        return
    fi
    if [[ -z "${MANGO_INSTANCE_SIGNATURE:-}" ]]; then
        echo "WARNING: MANGO_INSTANCE_SIGNATURE not set; WM watchdog inactive." >&2
        return
    fi

    mmsg watch all-monitors >/dev/null 2>&1

    kill -TERM "$$"
}

wm_watchdog &
WATCHDOG_PID=$!


queue=()

while true; do
    if [[ ${#queue[@]} -eq 0 ]]; then
        mapfile -t queue < <(shuf -e "${WALLPAPERS[@]}")
    fi

    wallpaper="${queue[0]}"
    queue=("${queue[@]:1}")

    [[ -n "$SWAYBG_PID" ]] && kill "$SWAYBG_PID" 2>/dev/null || true

    swaybg --image "$wallpaper" --mode "$MODE" &
    SWAYBG_PID=$!

    sleep "$INTERVAL"
done
