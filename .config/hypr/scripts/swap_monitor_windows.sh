#!/usr/bin/env bash
# Swap the windows between the workspaces active on DP-1 and DP-2
# (the workspaces stay on their monitor, only the windows move)
set -euo pipefail

read -r a b < <(hyprctl -j monitors | jq -r '
    [ (.[] | select(.name=="DP-1").activeWorkspace.id),
      (.[] | select(.name=="DP-2").activeWorkspace.id) ] | @tsv')

# addresses are collected before moving anything, so no temp workspace is needed
cmds=$(hyprctl -j clients | jq -r --argjson a "$a" --argjson b "$b" '
    .[] | select(.workspace.id == $a or .workspace.id == $b)
        | "dispatch hl.dsp.window.move({ workspace = \(if .workspace.id == $a then $b else $a end), follow = false, window = \"address:\(.address)\" })"' \
    | paste -sd';')

[ -n "$cmds" ] && hyprctl --batch "$cmds"
