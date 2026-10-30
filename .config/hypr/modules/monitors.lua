--------------------
---- MONITORS ----
--------------------

-- https://wiki.hypr.land/Configuring/Monitors/
-- G9 e Xiaomi per descrizione (modules/vars.lua): stessa disposizione sul fisso e sui
-- portatili in dock. Il resto dipende da `host`.

-- Dalla dock HP (Thunderbolt Dock G2) i due monitor condividono un solo collegamento DP
-- (MST, ~26 Gbit/s): G9 a 60 Hz + Xiaomi a 100 Hz è il massimo; col G9 a 120 Hz resta nero.
hl.monitor({
    output   = screens.main,
    mode     = profile.laptop and "5120x1440@60" or "5120x1440@144",
    position = "0x0",
    scale    = "1.066",
    vrr      = 0,   -- il G9 non annuncia adaptive sync: con misc.vrr = 2 ogni schermo intero tentava e rifaceva il modeset (nero)
})

hl.monitor({
    output   = screens.side,
    mode     = profile.laptop and "3440x1440@100" or "3440x1440@144",
    position = "auto-center-up",
    scale    = "1",
})

-- Qualsiasi altro schermo (proiettore, monitor in ufficio): risoluzione preferita, accanto
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "1" })

if host == "desktop" then
    -- Monitor verticale capovolto (Tasks)
    hl.monitor({
        output    = "HDMI-A-1",
        mode      = "1920x1080@60",
        position  = "auto-center-down",
        scale     = "1",
        transform = 2,
    })
end

if profile.laptop then
    local function panel(enabled, position)
        hl.monitor({
            output   = screens.panel,
            mode     = "preferred",
            position = position,
            scale    = "1",
            disabled = not enabled,
        })
    end

    local function lid_closed()
        local p = io.popen("cat /proc/acpi/button/lid/*/state 2>/dev/null")
        if not p then return false end
        local state = p:read("*a")
        p:close()
        return state:find("closed") ~= nil
    end

    local function external_connected()
        for _, m in ipairs(hl.get_monitors()) do
            if m.name ~= screens.panel then return true end
        end
        return false
    end

    -- Coperchio chiuso con monitor esterni: pannello spento. Senza esterni non si tocca
    -- (logind sospende; con un monitor esterno collegato invece ignora il coperchio).
    -- Posizione: sotto il G9 in dock, 0x0 da solo. Senza esterni auto-center-down lo mette a
    -- x = -960, e virt-viewer a schermo intero non ridimensiona la VM (SPICE scarta le x negative).
    local panel_state = nil
    local function update_panel(closed)
        local external = external_connected()
        local want = not (closed and external)
        local position = external and "auto-center-down" or "0x0"
        local state = tostring(want) .. " " .. position
        if state ~= panel_state then
            panel_state = state
            panel(want, position)
        end
    end

    update_panel(lid_closed())
    hl.bind("switch:on:Lid Switch",  function() update_panel(true)  end, { locked = true })
    hl.bind("switch:off:Lid Switch", function() update_panel(false) end, { locked = true })
    -- Dock collegata o staccata a coperchio chiuso
    hl.on("monitor.added",   function() update_panel(lid_closed()) end)
    hl.on("monitor.removed", function() update_panel(lid_closed()) end)
end
