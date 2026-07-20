#!/usr/bin/bash

status=$(playerctl status 2>/dev/null)

case "$status" in
    Playing)
        playerctl pause
        ;;
    Paused)
        playerctl play
        ;;
    *)

        ;;
esac
