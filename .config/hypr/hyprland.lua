require("modules/monitors")
require("modules/keybindings")
require("modules/autostart")
require("modules/rules")

------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")


-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Register the custom layout
hl.layout.register("custom_center2", {
    recalculate = function(ctx)
        local n = #ctx.targets
        
        if n == 0 then return end

        if n == 1 then
            local gap = 900
            ctx.targets[1]:place({
                x = math.floor(ctx.area.x + gap),
                y = math.floor(ctx.area.y),
                w = math.floor(ctx.area.w - (2 * gap)),
                h = math.floor(ctx.area.h)
            })

        elseif n == 2 then
            local gap = 200
            local win_w = math.floor((ctx.area.w - (2 * gap)) / 2)
            
            for i, target in ipairs(ctx.targets) do
                target:place({
                    x = math.floor(ctx.area.x + gap + ((i - 1) * win_w)),
                    y = math.floor(ctx.area.y),
                    w = win_w,
                    h = math.floor(ctx.area.h)
                })
            end

        else
            -- 3 or more Windows: Centered master with cascaded side decks
            local master_ratio = 0.5
            local master_w = math.floor(ctx.area.w * master_ratio)
            local side_w = math.floor((ctx.area.w - master_w) / 2)
            
            local left_count = math.ceil((n - 1) / 2)
            local right_count = math.floor((n - 1) / 2)
            
            -- Cascade settings
            local offset_step = 35 -- Pixels to shift each window down and right
            
            -- Place Left Stack (Cascading down and right)
            if left_count > 0 then
                -- Calculate how much space the cascade will consume so we can shrink the windows to fit
                local total_offset_w = (left_count - 1) * offset_step
                local total_offset_h = (left_count - 1) * offset_step
                
                local cascade_win_w = side_w - total_offset_w
                local cascade_win_h = math.floor(ctx.area.h) - total_offset_h

                for i = 1, left_count do
                    local target = ctx.targets[i + 1]
                    local current_offset = (i - 1) * offset_step
                    
                    target:place({
                        x = math.floor(ctx.area.x + current_offset),
                        y = math.floor(ctx.area.y + current_offset),
                        w = math.floor(cascade_win_w),
                        h = math.floor(cascade_win_h)
                    })
                end
            end
            
            -- Place Master window (Target 1 in the center)
            ctx.targets[1]:place({
                x = math.floor(ctx.area.x + side_w),
                y = math.floor(ctx.area.y),
                w = master_w,
                h = math.floor(ctx.area.h)
            })
            
            -- Place Right Stack (Cascading down and right)
            if right_count > 0 then
                local total_offset_w = (right_count - 1) * offset_step
                local total_offset_h = (right_count - 1) * offset_step
                
                local cascade_win_w = side_w - total_offset_w
                local cascade_win_h = math.floor(ctx.area.h) - total_offset_h

                for i = 1, right_count do
                    local target = ctx.targets[1 + left_count + i]
                    local current_offset = (i - 1) * offset_step
                    
                    target:place({
                        x = math.floor(ctx.area.x + side_w + master_w + current_offset),
                        y = math.floor(ctx.area.y + current_offset),
                        w = math.floor(cascade_win_w),
                        h = math.floor(cascade_win_h)
                    })
                end
            end
        end
    end
})

-- Register the custom layout
hl.layout.register("custom_center", {
    recalculate = function(ctx)
        local n = #ctx.targets
        
        -- Do nothing if there are no windows
        if n == 0 then return end

        if n == 1 then
            -- 1 Window: Center the master window with 900px horizontal gaps
            local gap = 900
            ctx.targets[1]:place({
                x = ctx.area.x + gap,
                y = ctx.area.y,
                w = ctx.area.w - (2 * gap),
                h = ctx.area.h
            })

        elseif n == 2 then
            -- 2 Windows: Center both with 200px gaps on the far left and far right
            local gap = 200
            local win_w = (ctx.area.w - (2 * gap)) / 2
            
            for i, target in ipairs(ctx.targets) do
                target:place({
                    x = ctx.area.x + gap + ((i - 1) * win_w),
                    y = ctx.area.y,
                    w = win_w,
                    h = ctx.area.h
                })
            end

        else
            -- 3 or more Windows: Centered master layout without extra gaps
            -- Master takes 50% of the screen in the center
            local master_ratio = 0.5
            local master_w = ctx.area.w * master_ratio
            local side_w = (ctx.area.w - master_w) / 2
            
            -- Divide remaining windows into left and right stacks
            local left_count = math.ceil((n - 1) / 2)
            local right_count = math.floor((n - 1) / 2)
            
            -- Place Left stack
            local left_h = ctx.area.h / left_count
            for i = 1, left_count do
                local target = ctx.targets[i + 1]
                target:place({
                    x = ctx.area.x,
                    y = ctx.area.y + ((i - 1) * left_h),
                    w = side_w,
                    h = left_h
                })
            end
            
            -- Place Master window (Target 1 in the center)
            ctx.targets[1]:place({
                x = ctx.area.x + side_w,
                y = ctx.area.y,
                w = master_w,
                h = ctx.area.h
            })
            
            -- Place Right stack
            if right_count > 0 then
                local right_h = ctx.area.h / right_count
                for i = 1, right_count do
                    local target = ctx.targets[1 + left_count + i]
                    target:place({
                        x = ctx.area.x + side_w + master_w,
                        y = ctx.area.y + ((i - 1) * right_h),
                        w = side_w,
                        h = right_h
                    })
                end
            end
        end
    end
})

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 20,

        border_size = 2,

        col = {
            active_border   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "lua:custom_center2",
    },

    decoration = {
        rounding       = 0,
        rounding_power = 0,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = true,
            size      = 3,
            passes    = 1,
            vibrancy  = 0.1696,
        },
        dim_around = 0.8,
    },

    animations = {
        enabled = true,
    },
})

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Default springs
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
       new_status = "slave",
       orientation ="center",
       focus_master_on_close = true,
       mfact = 0.45
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
       fullscreen_on_one_column = true,
       column_width = 0.35,
       focus_fit_method = 1,
       follow_focus = true,
       follow_min_visible = 0.5,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = -1,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = true, -- If true disables the random hyprland logo / anime girl background. :(
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout = "custom_xkb_layout",
        kb_variant = "",
        kb_model   = "",
        kb_options = "fkeys:basic_13-24",
        kb_rules   = "",
        repeat_delay = 100,
        repeat_rate = 50,
        
        natural_scroll = true,
        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
           natural_scroll = false,
           scroll_factor = 1,
           disable_while_typing = true,
        },
    },
})
