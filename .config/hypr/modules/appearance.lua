--------------------
---- APPEARANCE ----
--------------------

-- https://wiki.hypr.land/Configuring/Variables/
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 20,

        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        resize_on_border = false,
        allow_tearing    = false,

        layout = "lua:custom_center2",
    },

    decoration = {
        rounding       = 0,
        rounding_power = 1,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },

        dim_around = 0.8,
    },

    animations = {
        enabled = true,
    },

    misc = {
        force_default_wallpaper = -1,   -- 0/1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = true,
    },
})

-- No pop or slide on windows: just a gentle fade in/out.
hl.animation({ leaf = "windows",    enabled = false })
hl.animation({ leaf = "windowsOut", enabled = false })
hl.animation({ leaf = "border",     enabled = true, speed = 2, bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 1, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1, bezier = "default", style = "fade" })
