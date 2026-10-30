#!/usr/bin/env nix-shell
#!nix-shell -i bash -p whisper-cpp-vulkan
# Super+Alt+C: dettatura mandata allo scratchpad Claude (pypr "claude") senza mostrarlo.
# Prima pressione registra, la seconda trascrive e invia il testo a Claude con Invio.
# Niente hyprwhspr-rs: incollerebbe nella finestra attiva. Testo via kitty remote control
# (socket @kitty-claude, aperto dal comando in ~/.config/pypr/config.toml).
set -u
pid=$XDG_RUNTIME_DIR/dettatura-claude.pid
wav=$XDG_RUNTIME_DIR/dettatura-claude.wav
M=~/.local/share/hyprwhspr-rs/models
note() { notify-send -a Claude -h string:x-canonical-private-synchronous:dettatura-claude "$@"; }

if ! [ -f "$pid" ]; then
  pw-record --rate 16000 --channels 1 --format s16 "$wav" & echo $! > "$pid"
  note "Claude ascolta" "Super+Alt+C per inviare"
  exit
fi

kill "$(cat "$pid")"; rm -f "$pid"; sleep 0.2
note "Claude" "Trascrivo…"
text=$(whisper-cli -m "$M/ggml-large-v3-turbo-q8_0.bin" --vad -vm "$M/ggml-silero-v5.1.2.bin" \
  -f "$wav" -l it -nt -np \
  --prompt "Buongiorno, le invio la scheda di sicurezza aggiornata (SDS), con il codice UFI e la classificazione CLP." \
  2>/dev/null | tr '\n' ' ' | sed 's/^ *//; s/ *$//')
rm -f "$wav"
[ -n "$text" ] || { note "Claude" "Non ho sentito niente"; exit; }

# scratchpad non avviato (lazy) o chiuso con /exit: lo apre una volta
if ! kitten @ --to unix:@kitty-claude ls >/dev/null 2>&1; then
  pypr show claude
  for _ in $(seq 40); do kitten @ --to unix:@kitty-claude ls >/dev/null 2>&1 && break; sleep 0.25; done
  sleep 3 # tempo all'avvio di claude
fi
kitten @ --to unix:@kitty-claude send-text "$text"
sleep 0.3
kitten @ --to unix:@kitty-claude send-key enter
note "Inviato a Claude" "$text"
