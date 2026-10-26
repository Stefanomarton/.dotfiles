--------------------
---- WORKSPACES ----
--------------------

-- https://wiki.hypr.land/Configuring/Workspace-Rules/
-- 1-6 sul G9, 7-9 sullo Xiaomi: sul fisso e sui portatili in dock. Fuori dalla dock
-- i monitor non ci sono e i workspace restano sul pannello.

for i = 1, 6 do
    hl.workspace_rule({ workspace = i, monitor = screens.main, persistent = true })
end

for i = 7, 9 do
    hl.workspace_rule({ workspace = i, monitor = screens.side, persistent = true })
end

-- VM Windows a schermo intero nel workspace w11 (Super+Ctrl+W: vm_enter in keybindings.lua).
-- Fisso: Looking Glass, lanciato dal workspace (on_created_empty).
-- tm-laptop: on_created_empty non parte, quindi vm_enter lancia vm_launch se il viewer non c'è:
-- virt-viewer in kiosk, avvia la VM se è spenta e si chiude quando si spegne.
local vm_on_created = { desktop = "looking-glass-client -F" }
vm_launch = ({
    ["tm-laptop"] = "pgrep -x virt-viewer >/dev/null || { virsh -c qemu:///system start tm-windows11 2>/dev/null; "
                 .. "virt-viewer -c qemu:///system --attach --wait --kiosk --kiosk-quit on-disconnect tm-windows11; }",
})[host]

if vm_on_created[host] or vm_launch then
    hl.workspace_rule({
        workspace = "name:w11",
        monitor   = screens.main,
        no_rounding = true,
        decorate  = false,
        no_border = true,
        gaps_in   = 0,
        gaps_out  = 0,
        on_created_empty = vm_on_created[host],
    })
end

if vm_launch then
    hl.window_rule({
        name  = "vm-viewer",
        match = { class = "^virt-viewer$" },
        workspace = "name:w11",
    })
end

-- agent-deck: web UI a tutto schermo, quella locale (servizio utente agent-deck-web) con Super+Del
-- e quella del desktop via NetBird con Super+Shift+Del (menu.lua); ognuna finisce sempre nel suo workspace
for _, a in ipairs({
    { ws = "agents",         class = "chrome-127\\.0\\.0\\.1__.*",          rule = "agent-deck-web" },
    { ws = "agents-desktop", class = "chrome-100\\.124\\.206\\.219__.*",    rule = "agent-deck-web-desktop" },
}) do
    hl.workspace_rule({
        workspace = "name:" .. a.ws,
        monitor   = screens.main,
        layout    = "monocle",
        no_rounding = true,
        decorate  = false,
        no_border = true,
        gaps_in   = 0,
        gaps_out  = 0,
    })
    hl.window_rule({
        name      = a.rule,
        match     = { class = a.class },
        workspace = "name:" .. a.ws,
    })
end
