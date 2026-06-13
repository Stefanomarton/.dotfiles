-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
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

for i = 1, 6 do
    hl.workspace_rule({ workspace = i, monitor = "DP-1", persistent = true})
end

for i = 7, 9 do
    hl.workspace_rule({ workspace = i, monitor = "DP-2", persistent = true})
end

hl.workspace_rule({ workspace = "name:w11", no_rounding = true, decorate = false, gaps_in = 0, gaps_out = 0, no_border = true, monitor = "DP-1", on_created_empty = "looking-glass-client -F" })
