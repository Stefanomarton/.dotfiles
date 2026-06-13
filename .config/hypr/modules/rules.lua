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
