-- Hyprland configuration
-- https://wiki.hypr.land/Configuring/

require("modules/vars")        -- shared variables (mainMod, terminal, ...)
require("modules/env")         -- environment variables & permissions
require("modules/layouts")     -- custom layouts (must load before appearance)
require("modules/appearance")  -- general, decoration, animations, misc
require("modules/input")       -- keyboard, mouse, touchpad
require("modules/monitors")    -- physical monitor setup
require("modules/workspaces")  -- workspace rules
require("modules/rules")       -- window rules
require("modules/keybindings") -- key & mouse binds
require("modules/autostart")   -- startup commands
