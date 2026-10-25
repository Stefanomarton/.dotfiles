--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

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
         class = "kitty-yazi.*",

      },
      dim_around = true,
})

hl.window_rule({
      name = "nextcloud-floating",
      match = {
         class = "com.nextcloud.desktopclient.nextcloud",
      },
         stay_focused = false,
         float = true,
         center = true,
         monitor = screens.main,
})

hl.window_rule({
      name = "float-picker",
      match = {
         class = "xdg-desktop-portal-gtk"
      },
      float = true,
      center = true,
      size = {"(monitor_w*0.5)", "(monitor_h*0.5)"},
      monitor = screens.main
})

-- selettore di condivisione schermo (xdph)
hl.window_rule({
      name = "float-share-picker",
      match = {
         class = "^hyprland-share-picker$"
      },
      float = true,
      center = true,
      size = {"(monitor_w*0.5)", "(monitor_h*0.5)"},
      monitor = screens.main
})

-- barra "… is sharing a window/your screen" di Chromium: parcheggiata in uno special workspace
hl.window_rule({
      name = "hide-chromium-share-bar",
      match = {
         class = "^$",
         title = ".* is sharing (a window|your screen|this tab|a tab)\\.?",
      },
      workspace = "special:sharebar silent",
})


-- Zotero: every window but the main one is a popup (dialogs, Sci-Hub, "Progress" toasts)
hl.window_rule({
      name = "zotero-popups",
      match = {
         class = "^Zotero$",
      },
      float = true,
      center = true,
})

hl.window_rule({
      name = "zotero-main",
      match = {
         class = "^Zotero$",
         title = "^(.* - )?Zotero$",
      },
      tile = true,
})

-- the "Progress" toasts (PDF downloads, sync): bottom-right corner, without taking focus
hl.window_rule({
      name = "zotero-progress",
      match = {
         class = "^Zotero$",
         title = "^Progress$",
      },
      no_initial_focus = true,
      move = {"(monitor_w-window_w-20)", "(monitor_h-window_h-20)"},
})


-- popup dell'estensione Bitwarden (non l'app desktop, che ha classe Bitwarden)
hl.on("window.title", function(w)
    local prefix = "Bitwarden"
    if w.title:sub(1, #prefix) == prefix and w.class:lower() ~= "bitwarden" then
        hl.dispatch(hl.dsp.window.float({ action = "enable", window = w }))
        hl.dispatch(hl.dsp.window.resize({ x = 500, y = 800, relative = false, window = w }))
        hl.dispatch(hl.dsp.window.center({ window = w }))
    end
end)


--------------------
---- LAYER RULES ----
--------------------

-- Modal backdrop: when a picker is open, blur the WHOLE desktop behind it so it
-- stands out (paired with the dim scrim, Theme.dimAround). ignore_alpha = 0 blurs
-- the full-screen overlay, not just the card. Only the pickers (not the always-on
-- corner or the transient volume OSD).
hl.layer_rule({
    name  = "widget-blur",
    match = { namespace = "^(smart-picker|expose|clipboard-picker)$" },
    blur         = true,
    ignore_alpha = 0.0,
})

-- Pickers and the focus frame appear at once: without this, layersIn inherits the global speed 8 (800 ms popin)
hl.layer_rule({
    name    = "picker-no-anim",
    match   = { namespace = "^(smart-picker|expose|clipboard-picker|focus-frame)$" },
    no_anim = true,
})

-- Popup di dettatura (scripts/dettatura-emacs.sh): frame Emacs chiamato "dettatura"
hl.window_rule({
    name  = "dettatura-popup",
    match = { class = "emacs", title = "^dettatura$" },
    float   = true,
    center  = true,
    size    = {"(monitor_w*0.4)", "(monitor_h*0.35)"},
    monitor = screens.main,
})
