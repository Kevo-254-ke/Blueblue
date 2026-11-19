#!/usr/bin/env bash
set -u

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo 'Run this command as root.' >&2
    exit 1
fi
if ! command -v wondershaper >/dev/null 2>&1; then
    echo 'wondershaper is missing. Install it with: apt-get install wondershaper' >&2
    exit 1
fi

NIC=$(ip -o -4 route show default 2>/dev/null | awk 'NR == 1 {print $5}')
if [[ -z "$NIC" ]]; then
    echo 'Could not find the default IPv4 network interface.' >&2
    exit 1
fi

state_file=/home/limit
mkdir -p /home
touch "$state_file"
clear
printf '==============================\n     Limit Bandwidth Speed\n==============================\n'
if [[ $(cat "$state_file") == start ]]; then
    printf 'Status: ON\n'
else
    printf 'Status: OFF\n'
fi
printf 'Interface: %s\n' "$NIC"
printf '1. Start limit\n2. Stop limit\n0. Return\n'
read -r -p 'Select: ' choice

case "$choice" in
    1)
        read -r -p 'Maximum download rate (Kbps): ' down
        read -r -p 'Maximum upload rate (Kbps): ' up
        if [[ ! "$down" =~ ^[1-9][0-9]*$ || ! "$up" =~ ^[1-9][0-9]*$ ]]; then
            echo 'Enter positive whole-number rates in Kbps.' >&2
            exit 1
        fi
        if wondershaper -a "$NIC" -d "$down" -u "$up"; then
            printf 'start\n' > "$state_file"
            echo "Speed limit applied to $NIC."
        else
            echo 'wondershaper could not apply the requested limits.' >&2
            exit 1
        fi
        ;;
    2)
        if wondershaper -ca "$NIC"; then
            : > "$state_file"
            echo "Speed limit cleared from $NIC."
        else
            echo 'wondershaper could not clear the current limits.' >&2
            exit 1
        fi
        ;;
    0) exit 0 ;;
    *) echo 'Choose 1, 2, or 0.' >&2; exit 1 ;;
esac
