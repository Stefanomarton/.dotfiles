--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

hl.window_rule({
      name = "dim-aroud-scratchpads",
      match = {
         class = "kitty-yazi",

      },
      dim_around = true,
})

hl.window_rule({
      name = "nextcloud-floating",
      match = {
         class = "com.nextcloud.desktopclient.nextcloud",
      },
         stay_focused = true,
         float = true,
         center = true,
         monitor = "DP-1",
})

hl.window_rule({
      name = "float-picker",
      match = {
         class = "xdg-desktop-portal-gtk"
      },
      float = true,
      center = true,
      size = {"(monitor_w*0.5)", "(monitor_h*0.5)"},
      monitor = "DP-1"
})


hl.on("window.title", function(w)
    local prefix = "Bitwarden"
    if w.title:sub(1, #prefix) == prefix then
        local monitor = hl.get_active_monitor()
        if monitor == nil then
            return
        end
        local win = { width = 500, height = 800 }
        local pos = {
            x = math.floor((monitor.width  - win.width)  / 2),
            y = math.floor((monitor.height - win.height) / 2),
        }
        hl.dispatch(hl.dsp.window.float({ action = "enable", window = w }))
        hl.dispatch(hl.dsp.window.resize({ x = win.width, y = win.height, relative = false, window = w }))
        hl.dispatch(hl.dsp.window.move({ x = pos.x, y = pos.y, relative = false, window = w }))
    end
end)
