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

-- Portatile con un solo monitor esterno che non è della dock (HDMI, o USB-C che appare
-- come DP-x): 1-5 sul pannello, 6-9 sull'esterno. Le regole valgono solo per i workspace
-- nuovi, quindi entrando in questa modalità quelli già aperti si spostano.
if profile.laptop then
    local external_rules = {}   -- nome del monitor -> regole 1-9, accese solo quando serve
    local active = nil

    local function lone_external()
        local found = nil
        for _, m in ipairs(hl.get_monitors()) do
            if m.name ~= screens.panel then
                local d = m.description or ""
                if found or d:find("Odyssey G91F", 1, true) or d:find("Mi Monitor", 1, true) then
                    return nil
                end
                found = m.name
            end
        end
        return found
    end

    local function update_external()
        local ext = lone_external()
        if ext == active then return end
        if active then
            for _, r in ipairs(external_rules[active]) do r:set_enabled(false) end
        end
        active = ext
        if not ext then return end
        if not external_rules[ext] then
            local rules = {}
            for i = 1, 9 do
                rules[i] = hl.workspace_rule({
                    workspace = i, monitor = i <= 5 and screens.panel or ext, persistent = true,
                })
            end
            external_rules[ext] = rules
        else
            for _, r in ipairs(external_rules[ext]) do r:set_enabled(true) end
        end
        for i = 1, 9 do
            local target = i <= 5 and screens.panel or ext
            local ws = hl.get_workspace(i)
            if ws and ws.monitor and ws.monitor.name ~= target then
                hl.dispatch(hl.dsp.workspace.move({ workspace = i, monitor = target }))
            end
        end
    end

    update_external()
    hl.on("monitor.added",   update_external)
    hl.on("monitor.removed", update_external)
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
