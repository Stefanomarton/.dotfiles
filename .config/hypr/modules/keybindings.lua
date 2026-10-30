---------------------
---- KEYBINDINGS ----
---------------------

-- mainMod is defined in modules/vars.lua.
-- Apps and actions (with their shortcuts) are in modules/menu.lua, the menu shown while Super is held;
-- here only movement, workspaces, mouse and volume. See https://wiki.hypr.land/Configuring/Basics/Binds/

-- Super+j/slash/l/k: focus per direzione. In un gruppo (groups.lua) Super+l/k passano alla scheda
-- precedente/successiva; nel monocle alla finestra precedente/successiva (layoutmsg: cycle_next lì
-- non cambia la finestra visibile).
function nav_focus(direction, dy)
    local w, ws = hl.get_active_window(), hl.get_active_workspace()
    if dy ~= 0 and w and w.group and w.group.size > 1 then
        hl.dispatch(dy > 0 and hl.dsp.group.next() or hl.dsp.group.prev())
    elseif dy ~= 0 and ws and ws.tiled_layout == "monocle" then
        hl.dispatch(hl.dsp.layout(dy > 0 and "cyclenext" or "cycleprev"))
    else
        hl.dispatch(hl.dsp.focus({ direction = direction }))
    end
end

-- Super+Ctrl+j/slash: stringe/allarga la master; negli altri layout ridimensiona la finestra
function master_resize(delta)
    local ws = hl.get_active_workspace()
    if ws and ws.tiled_layout == "master" then
        hl.dispatch(hl.dsp.layout(string.format("mfact %+.2f", delta)))
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
    bind(mainMod .. " + j",     function() nav_focus("left", 0) end)
    bind(mainMod .. " + slash", function() nav_focus("right", 0) end)
    bind(mainMod .. " + l",     function() nav_focus("up", -1) end)
    bind(mainMod .. " + k",     function() nav_focus("down", 1) end)
    bind(mainMod .. " + space", hl.dsp.layout("focusmaster master"))        -- focus sulla master
    bind(mainMod .. " + SHIFT + space", hl.dsp.layout("swapwithmaster master"))  -- la attiva diventa master
    bind(mainMod .. " + CTRL + j",     function() master_resize(-0.05) end, { repeating = true })
    bind(mainMod .. " + CTRL + slash", function() master_resize(0.05) end,  { repeating = true })

    bind(mainMod .. "+ page_down", hl.dsp.window.cycle_next({next = false}))
    bind(mainMod .. "+ page_up", hl.dsp.window.cycle_next())

    -- Switch workspaces with mainMod + [1-9] (no workspace 10)
    -- Move active window to a workspace with ALT + [1-9] (no Super, on purpose),
    -- move and follow it with mainMod + CTRL + [1-9]
    for i = 1, 9 do
        bind(mainMod .. " + " .. i,             hl.dsp.focus({ workspace = i}))
        bind(" + ALT + " .. i,     hl.dsp.window.move({ workspace = i, follow=false }))
        bind(mainMod .. " + CTRL + " .. i, hl.dsp.window.move({ workspace = i, follow=true }))
    end

    -- Volume (repeats while held; capped at 100%)
    bind(mainMod .. " + Up",   hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
    bind(mainMod .. " + Down", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { repeating = true })

    bind(mainMod .. " + SHIFT + j",     hl.dsp.window.swap({ direction = "left" }))
    bind(mainMod .. " + SHIFT + slash", hl.dsp.window.swap({ direction = "right" }))

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
