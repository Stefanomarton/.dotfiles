--------------------
---- WORKSPACES ----
--------------------

-- https://wiki.hypr.land/Configuring/Workspace-Rules/
-- Per-host setup, keyed by `host` (see modules/vars.lua).

local setups = {}

setups.desktop = function()
    -- Persistent per-monitor workspaces
    for i = 1, 6 do
        hl.workspace_rule({ workspace = i, monitor = "DP-1", persistent = true })
    end

    for i = 7, 9 do
        hl.workspace_rule({ workspace = i, monitor = "DP-2", persistent = true })
    end

    -- Looking Glass VM workspace
    hl.workspace_rule({
        workspace = "name:w11",
        monitor   = "DP-1",
        no_rounding = true,
        decorate  = false,
        no_border = true,
        gaps_in   = 0,
        gaps_out  = 0,
        on_created_empty = "looking-glass-client -F",
    })

    -- Tasks workspace: monocle (one window at a time, fills the screen)
    hl.workspace_rule({
        workspace = "name:tasks",
        monitor   = "HDMI-A-1",
        gaps_in   = 0,
        gaps_out  = 0,
        layout    = "monocle",
        on_created_empty = "ticktick",
        persistent = true,
    })
end

setups.laptop = function()
    -- Single panel: no per-monitor pinning needed.
end

local apply = setups[host]
if apply then apply() end
