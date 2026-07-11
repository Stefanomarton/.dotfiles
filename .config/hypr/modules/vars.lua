-----------------------------
---- SHARED VARIABLES ----
-----------------------------

-- Global (no `local`) so every required module can reference them,
-- the same way Hyprland exposes the `hl` API globally.

mainMod     = "SUPER" -- main modifier ("Windows" key)
terminal    = "kitty"
fileManager = "nemo"

-- Current machine, so monitors/workspaces can differ per host (desktop, laptop, ...).
local function detect_host()
    local f = io.open("/etc/hostname", "r")
    if f then
        local h = f:read("*l")
        f:close()
        if h then
            h = h:gsub("%s+", "")
            if h ~= "" then return h end
        end
    end
    return os.getenv("HOSTNAME") or "unknown"
end

host = detect_host()
