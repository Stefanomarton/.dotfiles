---------------------
---- KEYBINDINGS ----
---------------------

-- Set programs that you use
local terminal    = "kitty"
local fileManager = "nemo"
local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())

hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("cliphist list | tofi | cliphist decode | wl-copy"))

hl.bind(mainMod .. "+ SHIFT + Q", hl.dsp.exit())

hl.bind(mainMod .. " + W", hl.dsp.global("quickshell:workspaces"))
hl.bind(mainMod .. " + P", hl.dsp.global("quickshell:windows"))

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

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.exec_cmd("pkill tofi || tofi-run | zsh"))

hl.bind(mainMod .. " + A",         hl.dsp.exec_cmd("pypr toggle yazi"))
hl.bind(mainMod .. " + X",         hl.dsp.exec_cmd("pypr toggle editor"))
hl.bind(mainMod .. " + I",         hl.dsp.exec_cmd("pypr toggle term"))
hl.bind(mainMod .. " + C",         hl.dsp.exec_cmd("pypr toggle qalc"))

hl.bind(mainMod .. "+ SHIFT + E",         hl.dsp.exec_cmd("emacs"))
hl.bind(mainMod .. "+ SHIFT + F",         hl.dsp.exec_cmd("chromium"))

hl.bind(mainMod .. "+ SHIFT + M",         hl.dsp.window.fullscreen())


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
        end, {long_press = true})
end)

-- screnshoots
hl.bind(mainMod .. "+ SHIFT + S", hl.dsp.exec_cmd([[
grim -g "$(slurp -d -c 00000000 -b 00000080)" - | wl-copy
]]))

hl.bind(mainMod .. "+ CTRL + SHIFT + S", hl.dsp.exec_cmd("~/.config/hypr/scripts/temp_screenshot.sh"))

hl.bind(mainMod .. "+ ALT + S", hl.dsp.exec_cmd([[
mkdir -p ~/inbox/screenshots && grim -g "$(slurp -d -c 00000000 -b 00000080)" ~/inbox/screenshots/"$(date +'%Y%m%dT%H%M%S')".png
]]))



local mainMod = "SUPER"

-- Helper function to keep our binds clean
local function set_workspace_layout(layout_name)
    -- 1. Fetch the data for the currently active workspace
    local active_ws = hl.get_active_workspace()
    
-- 2. Dynamically apply the workspace rule using the native Lua method
    hl.workspace_rule({
        workspace = active_ws.name,
        layout = layout_name
    })
end

-- Switch current workspace to Master
hl.bind(mainMod .. " + M", function()
    set_workspace_layout("lua:custom_center2")
end, { description = "Set current workspace to Master" })

-- Switch current workspace to Scrolling
hl.bind(mainMod .. " + D", function()
    set_workspace_layout("scrolling")
end, { description = "Set current workspace to Scrolling" })



hl.bind("mouse_right", hl.dsp.layout("move -500"), {mouse = true})
hl.bind("mouse_left", hl.dsp.layout("move +500"), {mouse = true})


hl.bind(mainMod .. "+ SHIFT + slash",
        hl.dsp.window.swap({direction = "right"}))

hl.bind(mainMod .. "+ SHIFT + j",
        hl.dsp.window.swap({direction = "left"}))

hl.bind(mainMod .. "+ SHIFT + k",
        hl.dsp.window.resize({x = 200, y = 0, relative = true}))

hl.bind(mainMod .. "+ SHIFT + l",
        hl.dsp.window.resize({x = -200, y = 0, relative = true}))


-- hl.bind(mainMod .. " + comma", hl.dsp.layout("swapcol l"))jjj
