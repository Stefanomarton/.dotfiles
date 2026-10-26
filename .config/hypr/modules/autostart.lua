hl.on("hyprland.start", function ()
         hl.exec_cmd("wl-paste --watch cliphist store")
         -- keep the clipboard when the app it was copied from closes
         hl.exec_cmd("wl-clip-persist --clipboard regular")
         hl.exec_cmd("udiskie")  -- automount USB drives, with a notification
         -- pypr 3.4.6 can die on a config reload (it loses the hyprctl socket mid-reload and
         -- the error notification fails too): restart it while this Hyprland instance is up
         hl.exec_cmd([[sh -c 'while [ -S "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock" ]; do pypr >> ~/.cache/pypr.log 2>&1; sleep 1; done']])
         hl.exec_cmd("hyprpaper")
         -- hyprsunset: servizio utente di NixOS (hyprland.nix), riavviato se cade
         -- Bitwarden (rbw, web.nix di NixOS): login con 2FA, sblocca il vault (avvia rbw-agent,
         -- socket SSH) e scrive in RAM le chiavi API lette dai programmi. Parte qui perché
         -- erediti WAYLAND_DISPLAY per la richiesta della master password
         hl.exec_cmd([[~/.local/bin/secrets-sync --login || notify-send -u critical "Segreti" "secrets-sync non riuscito: rilanciarlo"]])
         hl.exec_cmd("~/.local/bin/theme")   -- rimette l'ultimo tema (file in ~/.local/state/theme)
         hl.exec_cmd("qs -p ~/.config/hypr/widgets/workspaces/")
         hl.exec_cmd("qs -p ~/.config/hypr/widgets/corner/")
         hl.exec_cmd("qs -p ~/.config/hypr/widgets/volume/")
         hl.exec_cmd("qs -p ~/.config/hypr/widgets/recorder/")
         hl.exec_cmd("qs -p ~/.config/hypr/widgets/notifications/")
         hl.exec_cmd("qs -p ~/.config/hypr/widgets/whichkey/")
         hl.exec_cmd("qs -p ~/.config/hypr/widgets/pomodoro/")
         hl.exec_cmd("qs -p ~/.config/hypr/widgets/tasktimer/")

         -- feature homelab di NixOS
         if profile.personal then
            hl.exec_cmd("nextcloud")
            hl.exec_cmd("go-hass-agent run")
            hl.exec_cmd("tasks --hidden")  -- solo nel tray, pronta quando serve
         end

         -- rimappatura della tastiera interna
         if profile.laptop then
            hl.exec_cmd("kmonad ~/.config/kmonad/laptop.kbd")
         end
         end)
