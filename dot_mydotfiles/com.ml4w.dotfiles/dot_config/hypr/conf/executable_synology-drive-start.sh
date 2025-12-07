#!/usr/bin/env bash

LOGFILE="/tmp/synology-to-ws9.log"
echo "[$(date)] Script started" >> "$LOGFILE"

sleep 10

QT_QPA_PLATFORM=xcb QT_WAYLAND_DISABLE=1 /usr/bin/synology-drive "$@" >>"$LOGFILE" 2>&1 &

sleep 5

for i in {1..200}; do
    addr=$(
        /usr/bin/hyprctl -j clients 2>>"$LOGFILE" \
        | /usr/bin/jq -r '.[] | select(.class=="cloud-drive-ui") | .address' 2>>"$LOGFILE" \
        | head -n1
    )

    if [ -n "$addr" ] && [ "$addr" != "null" ]; then
        /usr/bin/hyprctl dispatch "movetoworkspacesilent 9,address:${addr}" >>"$LOGFILE" 2>&1
        exit 0
    fi

    sleep 0.1
done
