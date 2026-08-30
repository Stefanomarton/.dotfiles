---------------------
---- KEYBINDINGS ----
---------------------

-- terminal, fileManager and mainMod are defined in modules/vars.lua

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())

hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("cliphist list | tofi | cliphist decode | wl-copy"))

hl.bind(mainMod .. " + ALT + D", hl.dsp.exec_cmd("hyprwhspr-rs record toggle"))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mainMod .. "+ SHIFT + Q", hl.dsp.exit())

hl.bind(mainMod .. " + W", hl.dsp.global("quickshell:workspaces"))
hl.bind(mainMod .. " + P", hl.dsp.global("quickshell:windows"))
hl.bind(mainMod .. " + R", hl.dsp.global("quickshell:smart"))
hl.bind(mainMod .. " + M", hl.dsp.global("quickshell:movewindow"))
hl.bind(mainMod .. " + E", hl.dsp.global("quickshell:expose"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + j",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + slash", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + l",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + k",  hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. "+ page_down", hl.dsp.window.cycle_next({next = false}))
hl.bind(mainMod .. "+ page_up", hl.dsp.window.cycle_next())

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(" + ALT + " .. key,     hl.dsp.window.move({ workspace = i, follow=false }))
end

-- Swap the workspaces currently shown on DP-1 and DP-2
hl.bind(mainMod .. " + T", hl.dsp.workspace.swap_monitors({ monitor1 = "DP-1", monitor2 = "DP-2" }))

-- Volume (repeats while held; capped at 100%)
hl.bind(mainMod .. " + Up",   hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind(mainMod .. " + Down", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { repeating = true })

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.exec_cmd("pkill tofi || tofi-run | zsh"))

hl.bind(mainMod .. " + A",         hl.dsp.exec_cmd("pypr toggle yazi"))
hl.bind(mainMod .. " + X",         hl.dsp.exec_cmd("pypr toggle editor"))
hl.bind(mainMod .. " + I",         hl.dsp.exec_cmd("pypr toggle term"))
hl.bind(mainMod .. " + C",         hl.dsp.exec_cmd("pypr toggle qalc"))

hl.bind(mainMod .. "+ SHIFT + E",         hl.dsp.exec_cmd("emacs"))
hl.bind(mainMod .. "+ SHIFT + F",         hl.dsp.exec_cmd("chromium"))

hl.bind(mainMod .. "+ F",         hl.dsp.window.fullscreen())


-- Entering the submap
hl.bind(mainMod .. " + CTRL + W", function()
    hl.dispatch(hl.dsp.submap("clean"))
    hl.dispatch(hl.dsp.focus({ workspace = "name:w11" }))
end)

-- Defining the submap
hl.define_submap("clean", function()
    -- Exiting the submap
        hl.bind(mainMod .. " + CTRL + W", function()
        hl.dispatch(hl.dsp.submap("reset"))
        hl.dispatch(hl.dsp.focus({ workspace = "previous_per_monitor" }))
        end)
end)

-- screnshoots
hl.bind(mainMod .. "+ SHIFT + S", hl.dsp.exec_cmd([[
grim -g "$(slurp -d -c 00000000 -b 00000080)" - | wl-copy
]]))

hl.bind(mainMod .. "+ CTRL + SHIFT + S", hl.dsp.exec_cmd("~/.config/hypr/scripts/temp_screenshot.sh"))

hl.bind(mainMod .. "+ ALT + S", hl.dsp.exec_cmd([[
mkdir -p ~/inbox/screenshots && grim -g "$(slurp -d -c 00000000 -b 00000080)" ~/inbox/screenshots/"$(date +'%Y%m%dT%H%M%S')".png
]]))


-- Apply a layout to the current workspace. Numbered workspaces are matched by
-- number ("2"); named ones (negative id) need the "name:" selector.
local function set_workspace_layout(layout_name)
    local ws = hl.get_active_workspace()
    local selector = ws.name
    if not tostring(ws.name):match("^%d+$") then
        selector = "name:" .. ws.name
    end
    hl.workspace_rule({ workspace = selector, layout = layout_name })
end

-- On-switch HUD via Hyprland's built-in notifications.
-- Tune the look here: <icon:-1=none> <duration ms> <accent color> <message>.
local function notify_layout(label, color)
    hl.dispatch(hl.dsp.exec_cmd(
        "hyprctl notify -1 1200 '" .. color .. "' 'fontsize:21  " .. label .. "'"))
end

-- Layout keychord: SUPER + SHIFT + L, then one letter (submap auto-exits).
--   m = master   f = monocle   s = scrolling   d = dwindle
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.submap("layout"))

hl.define_submap("layout", function()
    local function pick(key, layout_name, label, color)
        local action = function()
            set_workspace_layout(layout_name)
            notify_layout(label, color)
            hl.dispatch(hl.dsp.submap("reset")) -- leave the submap
        end
        hl.bind(key, action)               -- shift released
        hl.bind("SHIFT + " .. key, action) -- ...or still held from entry
    end

    pick("m", "lua:custom_center2", "Master",    "rgb(89b4fa)")
    pick("f", "monocle",           "Monocle",   "rgb(cba6f7)")
    pick("s", "scrolling",         "Scrolling", "rgb(a6e3a1)")
    pick("d", "dwindle",           "Dwindle",   "rgb(fab387)")

    hl.bind("escape", hl.dsp.submap("reset")) -- cancel
end)



hl.bind("mouse_right", hl.dsp.layout("move -500"), {mouse = true})
hl.bind("mouse_left", hl.dsp.layout("move +500"), {mouse = true})


hl.bind(mainMod .. "+ SHIFT + slash",
        hl.dsp.window.swap({direction = "right"}))

hl.bind(mainMod .. "+ SHIFT + j",
        hl.dsp.window.swap({direction = "left"}))

hl.bind(mainMod .. "+ SHIFT + k",
        hl.dsp.window.resize({x = 200, y = 0, relative = true}))


-- hl.bind(mainMod .. " + comma", hl.dsp.layout("swapcol l"))jjj
