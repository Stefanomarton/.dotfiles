# Hyprland + widget Quickshell

Config Hyprland in Lua (`hyprland.lua` → `modules/*.lua`) e widget Quickshell in `widgets/`,
uno per cartella, ognuno avviato da `modules/autostart.lua` con `qs -p <cartella>`.
Gira su desktop (G9 + Xiaomi) e sui portatili (`laptop`, `tm-laptop`): profili in `modules/vars.lua`.

## Scorciatoie e menu

- `modules/menu.lua`: **una tabella** per le scorciatoie di app/azioni e per il menu which-key.
  Nel menu il tasto è la scorciatoia senza Super (Super+N veloce = Super tenuto, poi N).
  Le sezioni sono solo titoli; l'unico accordo è Layout (Shift+L, poi m/f/s/d).
  Al caricamento scrive `$XDG_RUNTIME_DIR/whichkey.json`, che il widget legge; il widget esegue
  la voce scelta con `Hyprland.dispatch('function() whichkey_run("3.9.1") end')` (in-process, niente `hyprctl`).
- `modules/keybindings.lua`: solo movimento, workspace, volume, mouse (`navigation_binds`),
  ripetuti anche nel submap `whichkey` perché restino attivi col menu aperto.
  Quindi i tasti del menu non possono essere cifre, j/k/l, slash, frecce, Esc, Backspace.
- Tenere Super: `widgets/whichkey` apre il menu dopo `holdDelay` (Config.qml) e mette Hyprland
  nel submap `whichkey`. Non si apre se il puntatore si è mosso (Super+trascina), se è aperto un
  pannello con la tastiera (`blockers`) o se nel frattempo è scattata una scorciatoia
  (`whichkey-cancel`). Si chiude da solo `autoClose` ms dopo il rilascio di Super.
- Gruppi (schede): `modules/groups.lua`. Super+G = `group_smart` (in un gruppo blocca/sblocca;
  fuori entra nel gruppo del workspace o ne crea uno), Super+Shift+G scompone (`group_dissolve`), Super+l/k scorrono le schede (`nav_focus`).
  App di messaggi (`MESSAGING`, pattern sulla classe) sempre in un gruppo bloccato. Colori della
  barra da `apply_theme()`.
- Layout di default: Master standard al centro (`layouts.lua`; il layout a carte è stato tolto).
  Su G9 e Xiaomi, workspace 1-9, margini laterali con 1 finestra (900) e 2 (500 sul G9, 200 sullo Xiaomi) via regole
  di workspace `w[tv1]`/`w[tv2]`. La pila diventa gruppi (`stack_normalize` in `groups.lua`):
  G9/Xiaomi fino a 3 finestre senza gruppi, dalla 4ª un gruppo per lato; portatile master + un
  gruppo. I gruppi fatti così si sciolgono quando le finestre calano; chiusa la master, la scheda
  visibile del gruppo diventa master. Usa `group:remove`, non `move out_of_group` (dà sempre il
  focus e fa saltare di workspace).
  Super+S, Ctrl+Invio su una finestra: `bring_master` (groups.lua) la porta qui e la fa master.
  Dopo spostamenti e chiusure la normalizzazione aspetta 30 ms: nell'evento il layout è vecchio.
- Super+Esc = `clean_screen` in menu.lua: nasconde scratchpad (`pypr hide '*'`), popup,
  picker, menu, tofi, rofi.
- Super+Ctrl+W = VM Windows a schermo intero nel workspace `w11` (voce del menu → `vm_enter` in
  keybindings.lua; submap `clean`: le altre scorciatoie vanno alla VM). Il viewer per host è in
  `modules/workspaces.lua`: Looking Glass sul fisso (`on_created_empty`), virt-viewer `--kiosk` su
  tm-laptop, lanciato da `vm_enter` (`vm_launch`) perché lì `on_created_empty` non parte.
  L'uscita ha `dont_inhibit` (= `bindp`), perché il viewer blocca le scorciatoie di Hyprland
  quando prende la tastiera.
- Super+P = rofi-rbw su rofi, tema in `.config/rofi/config.rasi` (fuzzel 1.14 non ha più
  `--override`, che rofi-rbw usa per le scorciatoie). Bitwarden via rbw; rbw, rofi e `SSH_AUTH_SOCK` in
  `~/.nixos/modules/web.nix`). Al login `~/.local/bin/secrets-sync` (autostart) sblocca il vault
  e scrive le chiavi API in RAM; l'elenco è nel vault (cartella `desktop`, username = percorso),
  un segreto nuovo si aggiunge con `~/.local/bin/secret-put`.
- Super+B = `~/.local/bin/rdp-borsini`: VM Windows di Borsini in Remmina (profilo salvato),
  password dal vault (`rdp borsini`) scritta in una copia del profilo in RAM.

## Widget

| Cartella | Cosa | Note |
|---|---|---|
| `shared/Theme.qml` | colori (da `theme.json`), font, `textScale` | tutti i `Theme.qml` sono symlink a questo |
| `whichkey` | menu tenendo Super | |
| `notifications` | server notifiche (al posto di dunst) | Super+N/Shift+N/Ctrl+N/Alt+N, Super+D non disturbare |
| `recorder` | badge e popup di `~/.local/bin/meet-rec` | la registrazione è il servizio utente `meet-rec` |
| `volume` | OSD del volume | |
| `workspaces` | Smart picker (Super+S), exposé, `pickers-close` | ordinamento in `rank.js`: `node rank_test.js` |
| `corner` | nome del workspace in ogni monitor | |
| `pomodoro` | cornice dello schermo col timer | Super+O poi s/p/n/x; colori del tema: danger = lavoro, ok = pausa, warning = timer fermo |
| `tasktimer` | badge in alto a sinistra col timer di Tasks in corso (avviato anche da web o telefono) | Super+Shift+O poi s (scegli il task in rofi, `pick.sh`) / x; clic sul badge = ferma; tutto via `tasks-cli` (flake tasks), sondaggio ogni 30 s |

- Schermo dei popup: lista `monitors` in ogni Config.qml, primo collegato vince:
  `["Odyssey G91F", "eDP-1"]` = G9 (desktop o portatile in dock), altrimenti pannello; mai Xiaomi.
- Tema: **una sola fonte**, `~/.local/bin/theme` (chiaro / scuro / nero = token Tesla di lettore-dwd).
  Super+Shift+T poi c/s/n. Scrive `~/.local/state/theme/`
  (fuori dal repo) e lo applica al volo: widget (`Theme.qml` guarda `theme.json`), bordi e
  rounding (`apply_theme()` in `modules/appearance.lua`, via `hyprctl dispatch`), kitty (SIGUSR1),
  GTK (gsettings + `gtk.css`); rofi e tofi alla prossima apertura. All'avvio `autostart.lua`
  rilancia `theme` senza argomenti (l'ultimo scelto). `theme check` controlla l'output.
  Colori nuovi: aggiungerli in `THEMES` dello script, poi in `Theme.qml` (JsonAdapter + proprietà).
  Nomi che iniziano con `on` + maiuscola (`onAccent`) in QML sono gestori di segnale: non usarli.
  Cornice dell'accento solo sui pannelli che prendono la tastiera (menu, picker, cronologia).
  Font unico JuliaMono (anche kitty, Emacs, GTK, Qt). Testo ×1.3 se c'è il G9 (`textScale`).

## Trappole (scoperte a caro prezzo)

- **Funzione-bind + `global`**: se una funzione Lua legata a un tasto fa
  `hl.dispatch(hl.dsp.global(...))`, Hyprland la riesegue al rilascio del tasto
  (Super+A apriva e richiudeva yazi). Dentro le funzioni usare `qs_send(name)`
  (keybindings.lua), che passa da `hyprctl`. `qs_dsp()` in menu.lua solo per bind non-funzione.
- **Global e rilascio**: una bind `global` manda al widget sia `pressed` (tasto giù) sia
  `released` (tasto su); una bind con `{ release = true }` non serve. Il long press di
  Hyprland segue `repeat_delay` (100 ms qui): inutilizzabile come "tieni premuto".
- **Process condiviso in QML**: un `Process` già in esecuzione ignora un nuovo `running = true`;
  per comandi rapidi in sequenza usare `Quickshell.execDetached`.
- **Live reload di Quickshell**: `sed -i` sostituisce il file e il watcher lo perde; modificare
  in place (Edit/python). Le istanze si chiamano `quickshell`, non `qs`: `pkill -f "qs -p …"`
  non le trova e `pgrep -f` col percorso trova anche la propria shell. Nemmeno `pgrep -x quickshell`:
  il nome del processo è `.quickshell-wra` (wrapper Nix). Va bene
  `pgrep -f '^/nix/store/[^ ]*quickshell -p .*<widget>'`; contare le istanze dopo ogni riavvio
  (copie doppie = più picker uno sopra l'altro, flash nero, Super+S che non richiude).
  Riavviarle da Hyprland (`hyprctl dispatch 'hl.dsp.exec_cmd("qs -p …")'`), non dalla shell.
- **Test dei tasti**: `wtype` non fa scattare le bind di Hyprland (tastiera virtuale);
  serve un dispositivo uinput (python-evdev). Non farlo mentre Stefano usa il PC.
- **pypr 3.4.6** può morire a un reload della config (perde il socket di hyprctl e fallisce
  anche la notifica d'errore): gira in un ciclo in autostart, log in `~/.cache/pypr.log`.
- **Sessione Hyprland riavviata**: `HYPRLAND_INSTANCE_SIGNATURE` della shell resta vecchio
  ("Couldn't connect"); prendere il più recente in `/run/user/1000/hypr/`.
- **Alt+numero senza Super** (sposta la finestra nel workspace) è voluto, non è un refuso:
  in cc7cf03 era diventato Super+Shift+numero ed è stato rimesso. Super+Ctrl+numero sposta e segue.
- **Finestre di prova Quickshell**: anche sul layer `Background` si vedono sopra il wallpaper
  (workspace vuoto). Per misure senza disturbare: niente finestra, o 4×4 px trasparente.
  `pkill -f <pattern>` uccide anche la shell che lo lancia se il pattern è nella sua riga.
- **Socket di Hyprland dai widget** (`Socket` di Quickshell.Io, una richiesta per connessione): usare
  le richieste `j/…`. La forma semplice (`cursorpos`) risponde senza a capo e lo `SplitParser`
  non emette mai la riga (whichkey non si apriva più). Chiudere la connessione dopo la `}`
  finale, altrimenti un avviso `PeerClosedError` a ogni richiesta.
- **Monitor a x negativa**: virt-viewer a schermo intero non ridimensiona la VM (SPICE
  `assertion 'x >= 0' failed`). Il pannello da solo sta in `0x0` (monitors.lua): con
  `auto-center-down` senza G9 finiva a x = -960.
- **Autopush**: il repo `.dotfiles` ha un hook post-commit che pubblica subito ogni commit.
  Controllare lo staging prima di committare (una cancellazione già in stage finisce dentro).

## Aperto

- `.zshrc` ed `emacs` hanno modifiche non committate di un'altra sessione.
