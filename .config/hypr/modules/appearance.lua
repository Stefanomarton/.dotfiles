--------------------
---- APPEARANCE ----
--------------------

-- https://wiki.hypr.land/Configuring/Variables/
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 20,

        border_size = 2,   -- colours: apply_theme() below

        resize_on_border = false,
        allow_tearing    = false,

        layout = "master",   -- master al centro, le altre ai lati (layouts.lua)
    },

    decoration = {
        rounding_power = 1,   -- rounding: apply_theme() below

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {   -- colour: apply_theme() below
            enabled      = true,
            range        = 4,
            render_power = 3,
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
        focus_on_activate       = true,  -- clic su una notifica (es. sessione Claude in kitty) porta alla sua finestra
        vrr                     = 2,     -- adaptive sync only for fullscreen apps (video, games)
    },

    xwayland = {
        force_zero_scaling = true,  -- X11 apps sharp on fractional-scale monitors instead of blurry
    },

    -- Auto HDR passava il G9 in HDR a ogni finestra a schermo intero (Tasks sul ws 3):
    -- modeset = schermo nero, e l'avviso "not in 10-bit mode" (il G9 è a 8 bit)
    render = {
        cm_auto_hdr = 0,
    },
})

-- Border colours, rounding and shadow from the desktop theme, the same as the widgets.
-- ~/.local/bin/theme writes the file and calls this (hyprctl dispatch), no reload needed.
-- Without the file (first login, before `theme` runs): the "nero" theme.
function apply_theme()
    local ok, t = pcall(dofile, os.getenv("HOME") .. "/.local/state/theme/hypr.lua")
    if not ok then
        t = { active = "rgba(7a9bf5ee)", active2 = "rgba(7a9bf5ee)", inactive = "rgba(2c2c31aa)",
              shadow = "rgba(00000000)", accent = "rgb(7a9bf5)", radius = 4,
              surface = "rgb(0d0d0d)", ink = "rgb(f2f2f2)", accent_text = "rgb(0a0f1c)", warn = "rgb(e6b071)" }
    end
    theme_accent = t.accent   -- the layout HUD in menu.lua
    hl.config({
        general    = { col = { active_border = { colors = { t.active, t.active2 }, angle = 45 },
                               inactive_border = t.inactive } },
        decoration = { rounding = t.radius, shadow = { color = t.shadow } },
        -- gruppi (groups.lua): bloccato = colore di avviso
        group      = { col = { border_active = t.active, border_inactive = t.inactive,
                               border_locked_active = t.warn, border_locked_inactive = t.inactive },
                       groupbar = { col = { active = t.accent, inactive = t.surface,
                                            locked_active = t.warn, locked_inactive = t.surface },
                                    text_color = t.accent_text, text_color_inactive = t.ink,
                                    text_color_locked_active = t.accent_text,
                                    text_color_locked_inactive = t.ink } },
    })
end
apply_theme()

-- No pop or slide on windows: just a gentle fade in/out.
hl.animation({ leaf = "windows",    enabled = false })
hl.animation({ leaf = "windowsOut", enabled = false })
hl.animation({ leaf = "border",     enabled = true, speed = 2, bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 1, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1, bezier = "default", style = "fade" })
