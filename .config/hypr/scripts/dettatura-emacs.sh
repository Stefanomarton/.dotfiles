#!/usr/bin/env bash
# Super+Alt+E: dettatura da rivedere in un popup Emacs prima di incollarla.
# Senza argomenti apre il popup e avvia la registrazione; allo stop (Super+Alt+D)
# hyprwhspr-rs incolla nella finestra attiva, cioè nel popup.
# `incolla ADDR CLASS` (da Emacs, C-c C-c) torna alla finestra di partenza e incolla;
# senza ADDR CLASS incolla nella finestra attiva (Enter negli appunti, Super+V).
# `modifica ID` (Ctrl+Enter negli appunti) apre il popup con la voce ID di cliphist, senza registrare.
set -eu

active() { hyprctl activewindow -j | jq -r '"\(.address) \(.class)"'; }

if [ "${1:-}" = incolla ]; then
  if [ $# -ge 3 ]; then addr=$2 class=$3; else read -r addr class < <(active); fi
  [ "$addr" != null ] || exit 0
  key=v
  case "$class" in
    kitty|foot|Alacritty|org.wezfurlong.wezterm|com.mitchellh.ghostty) mods="ctrl shift" ;;
    emacs) mods="shift" key=Insert ;; # Ctrl+V scrolls in Emacs
    *) mods="ctrl" ;;
  esac
  hyprctl dispatch "hl.dsp.focus({ window = 'address:$addr' })" >/dev/null
  sleep 0.15
  hyprctl dispatch "hl.dsp.send_shortcut({ mods = '$mods', key = '$key', window = 'address:$addr' })" >/dev/null
  exit
fi

read -r addr class < <(active)

if [ "${1:-}" = modifica ]; then
  f=$(mktemp -p "$XDG_RUNTIME_DIR" appunti.XXXXXX)
  cliphist decode "$2" > "$f"
  emacsclient -c -n -F '((name . "dettatura"))' -e "(dettatura-apri \"$addr\" \"$class\" \"$f\")" >/dev/null
  exit
fi

emacsclient -c -n -F '((name . "dettatura"))' -e "(dettatura-apri \"$addr\" \"$class\")" >/dev/null
hyprwhspr-rs record start >/dev/null
