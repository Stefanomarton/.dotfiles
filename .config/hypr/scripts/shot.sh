#!/usr/bin/env bash
# Screenshot: shot.sh area|window clip|inbox (menu.lua, Super+Shift+S then s/S/f/F).
set -euo pipefail

sleep 0.15 # the which-key menu has to be gone from the screen first

case "${1:-}" in
    area) geometry=$(slurp -d -c 00000000 -b 00000080) || exit 0 ;;
    window) geometry=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"') ;;
    *) echo "usage: shot.sh area|window clip|inbox" >&2; exit 2 ;;
esac

case "${2:-}" in
    clip)
        grim -g "$geometry" - | wl-copy --type image/png
        notify-send -t 1500 "Screenshot" "Negli appunti"
        ;;
    inbox)
        dir="$HOME/inbox/screenshots"
        mkdir -p "$dir"
        file="$dir/$(date +%Y%m%dT%H%M%S).png"
        grim -g "$geometry" "$file"
        notify-send -t 2500 "Screenshot" "$file"
        ;;
    *) echo "usage: shot.sh area|window clip|inbox" >&2; exit 2 ;;
esac
