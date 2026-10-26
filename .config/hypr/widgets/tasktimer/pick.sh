#!/usr/bin/env bash
# Super+Shift+O, s: an open task picked in rofi (the late and today's first: list_tasks sorts by date), its timer started.
# Blocks are left out (a block is time, not work). A failure is a notification.
fail() { notify-send -a Tasks "Timer non avviato" "$1"; exit 1; }
list=$(tasks-cli tool list_tasks '{"limit": 300}' 2>&1) || fail "$list"
pick=$(jq -r '.tasks[] | select(.kind != "block") | "\(.title)\(if .due_date != "" then "   · \(.due_date)" else "" end)\t\(.id)"' <<<"$list" |
  rofi -dmenu -i -p "Timer" -display-columns 1 -display-column-separator '\t') || exit 0
out=$(tasks-cli start "${pick##*$'\t'}" 2>&1) || fail "$out"
