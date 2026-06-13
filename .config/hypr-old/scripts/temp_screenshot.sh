#!/usr/bin/env bash
tmpfile=$(mktemp --suffix=.png)
grim -g "$(slurp -d -c 00000000 -b 00000080)" "$tmpfile" &&
	hyprctl dispatch exec "[float] imv $tmpfile" &&
	sleep 1 && rm "$tmpfile"
