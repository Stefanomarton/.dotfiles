--------------------
---- MONITORS ----
--------------------

-- https://wiki.hypr.land/Configuring/Monitors/
-- Per-host setup, keyed by `host` (see modules/vars.lua).

local setups = {}

setups.desktop = function()
    hl.monitor({
        output   = "DP-1",
        mode     = "5120x1440@144",
        position = "0x0",
        scale    = "1.066",
    })

    hl.monitor({
        output   = "DP-2",
        mode     = "3440x1440@144",
        position = "auto-center-up",
        scale    = "1",
    })

    hl.monitor({
        output    = "HDMI-A-1",
        mode      = "1920x1080@60",
        position  = "auto-center-down",
        scale     = "1",
        transform = 2,
    })
end

setups.laptop = function()
    -- TODO: adjust for the laptop panel (output name / mode / scale).
    hl.monitor({
        output   = "eDP-1",
        mode     = "preferred",
        position = "auto",
        scale    = "1",
    })
end

-- Unknown host: let Hyprland auto-configure every connected output.
local function fallback()
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "1" })
end

local apply = setups[host] or fallback
apply()
