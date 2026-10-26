---------------------
---- KEYBINDINGS ----
---------------------

-- mainMod is defined in modules/vars.lua.
-- Apps and actions (with their shortcuts) are in modules/menu.lua, the menu shown while Super is held;
-- here only movement, workspaces, mouse and volume. See https://wiki.hypr.land/Configuring/Basics/Binds/

-- Layout a carte (custom_center2), secondo deck_columns (layouts.lua): Super+j/slash passano alla
-- colonna accanto, sulla carta usata più di recente; Super+l/k alla carta sopra/sotto nella stessa
-- colonna; Super+Shift+j/slash scambiano la finestra con quella della colonna accanto (niente
-- Shift+l: è il menu dei layout). Altrove, o dove la colonna finisce, focus/swap per direzione.
local function deck_layout()
    local ws = hl.get_active_workspace()
    return ws and ws.tiled_layout == "lua:custom_center2" and ws or nil
end

-- la carta della colonna usata più di recente (quella che si vede sopra le altre)
local function top_card(col)
    local history = {}
    for _, w in ipairs(hl.get_windows()) do history[w.address] = w.focus_history_id end
    local best, best_id = col[#col], math.huge
    for _, addr in ipairs(col) do
        local id = history[addr]
        if id and id >= 0 and id < best_id then best, best_id = addr, id end
    end
    return best
end

-- selettore della finestra a dx colonne (dx ~= 0) o dy carte (dy ~= 0) da quella attiva
local function deck_target(dx, dy)
    local w, ws = hl.get_active_window(), deck_layout()
    local cols = w and ws and deck_columns[ws.id]
    for c, col in ipairs(cols or {}) do
        for i, addr in ipairs(col) do
            if addr == w.address then
                local target
                if dx ~= 0 then
                    target = cols[c + dx] and #cols[c + dx] > 0 and top_card(cols[c + dx])
                else
                    target = col[i + dy]
                end
                return target and "address:" .. target
            end
        end
    end
end

function deck_focus(direction, dx, dy)
    -- monocle: le finestre sono una sopra l'altra, Super+l/k passano alla precedente/successiva
    local ws = hl.get_active_workspace()
    if dy ~= 0 and ws and ws.tiled_layout == "monocle" then
        hl.dispatch(hl.dsp.window.cycle_next({ next = dy > 0 }))
        return
    end
    local target = deck_target(dx, dy)
    hl.dispatch(target and hl.dsp.focus({ window = target }) or hl.dsp.focus({ direction = direction }))
end

function deck_swap(direction, dx, dy)
    local target = deck_target(dx, dy)
    hl.dispatch(target and hl.dsp.window.swap({ target = target }) or hl.dsp.window.swap({ direction = direction }))
end

-- Super+Space: focus sulla master; Super+Shift+Space: la finestra attiva prende il posto della master
local function deck_master_addr()
    local ws = deck_layout()
    return ws and deck_master[ws.id]
end

function focus_master()
    local addr = deck_master_addr()
    if addr then hl.dispatch(hl.dsp.focus({ window = "address:" .. addr })) end
end

function swap_with_master()
    local addr, w = deck_master_addr(), hl.get_active_window()
    if addr and w and w.address ~= addr then
        hl.dispatch(hl.dsp.window.swap({ target = "address:" .. addr }))
    end
end

-- Super+Ctrl+j/slash: stringe/allarga la master; negli altri layout ridimensiona la finestra
function deck_resize(delta)
    if deck_layout() then
        hl.dispatch(hl.dsp.layout(string.format("ratio %+.2f", delta)))
    else
        hl.dispatch(hl.dsp.window.resize({ x = delta > 0 and 100 or -100, y = 0, relative = true }))
    end
end

-- Movement, workspaces, volume and mouse. A function because the which-key submap
-- (modules/menu.lua) binds them again, with `after` closing the menu, so they keep
-- working however long Super is held. Here `after` tells the menu a shortcut fired, so
-- holding Super after Super+1 doesn't open it.
function navigation_binds(after)
    local function bind(keys, action, opts)
        if after and not (opts and opts.mouse) then   -- drag/resize must stay mouse dispatchers
            local run = action
            action = function()
                if type(run) == "function" then run() else hl.dispatch(run) end
                after()
            end
        end
        hl.bind(keys, action, opts)
    end

    bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
    bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    -- Move focus with mainMod + arrow keys
    bind(mainMod .. " + j",     function() deck_focus("left", -1, 0) end)
    bind(mainMod .. " + slash", function() deck_focus("right", 1, 0) end)
    bind(mainMod .. " + l",     function() deck_focus("up", 0, -1) end)
    bind(mainMod .. " + k",     function() deck_focus("down", 0, 1) end)
    bind(mainMod .. " + space", focus_master)
    bind(mainMod .. " + SHIFT + space", swap_with_master)
    bind(mainMod .. " + CTRL + j",     function() deck_resize(-0.05) end, { repeating = true })
    bind(mainMod .. " + CTRL + slash", function() deck_resize(0.05) end,  { repeating = true })

    bind(mainMod .. "+ page_down", hl.dsp.window.cycle_next({next = false}))
    bind(mainMod .. "+ page_up", hl.dsp.window.cycle_next())

    -- Switch workspaces with mainMod + [0-9]
    -- Move active window to a workspace with ALT + [0-9] (no Super, on purpose),
    -- move and follow it with mainMod + CTRL + [0-9]
    for i = 1, 10 do
        local key = i % 10 -- 10 maps to key 0
        bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
        bind(" + ALT + " .. key,     hl.dsp.window.move({ workspace = i, follow=false }))
        bind(mainMod .. " + CTRL + " .. key, hl.dsp.window.move({ workspace = i, follow=true }))
    end

    -- Volume (repeats while held; capped at 100%)
    bind(mainMod .. " + Up",   hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
    bind(mainMod .. " + Down", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { repeating = true })

    bind(mainMod .. " + SHIFT + j",     function() deck_swap("left", -1, 0) end)
    bind(mainMod .. " + SHIFT + slash", function() deck_swap("right", 1, 0) end)

    bind(mainMod .. "+ SHIFT + k",
            hl.dsp.window.resize({x = 200, y = 0, relative = true}))
end

-- Send a Quickshell shortcut from inside a Lua function bind. Not hl.dispatch(hl.dsp.global()):
-- a function bind that dispatches `global` is run again when the key is released, so Super+A
-- opened yazi on press and closed it on release. Through hyprctl it is not tied to the key.
function qs_send(name)
    hl.dispatch(hl.dsp.exec_cmd([[hyprctl dispatch 'hl.dsp.global("quickshell:]] .. name .. [[")']]))
end

navigation_binds(function() qs_send("whichkey-cancel") end)


-- Entering the submap: Super+Ctrl+W, bound in menu.lua so it shows in the which-key menu.
-- vm_launch (workspaces.lua) starts the viewer where on_created_empty doesn't
function vm_enter()
    hl.dispatch(hl.dsp.submap("clean"))
    hl.dispatch(hl.dsp.focus({ workspace = "name:w11" }))
    if vm_launch then hl.dispatch(hl.dsp.exec_cmd(vm_launch)) end
end

-- Defining the submap
hl.define_submap("clean", function()
    -- Exiting the submap. dont_inhibit (bindp): the viewer grabs the keyboard for the VM,
    -- this key still reaches Hyprland
        hl.bind(mainMod .. " + CTRL + W", function()
        hl.dispatch(hl.dsp.submap("reset"))
        hl.dispatch(hl.dsp.focus({ workspace = "previous_per_monitor" }))
        end, { dont_inhibit = true })
end)


-- hl.bind(mainMod .. " + comma", hl.dsp.layout("swapcol l"))jjj
