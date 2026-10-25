------------------------
---- MENU (which-key) ----
------------------------

-- One table for the shortcuts and for the menu shown while Super is held
-- (widgets/whichkey). Rule: the key in the menu is the shortcut without Super, so
-- Super+N quick and Super held then N do the same thing. Sections are only headings.
--   { "label", run, bind }   run = shell command, hl.dsp.* or Lua function; bind = the shortcut
--   { "label", bind = ..., group = { { "key", "label", run }, ... } }   a chord: bind, then key
-- At load the table is written to $XDG_RUNTIME_DIR/whichkey.json for the overlay, which
-- runs the chosen entry back here through whichkey_run(). Movement, workspaces, mouse and
-- volume are in modules/keybindings.lua (navigation_binds).

-- Apply a layout to the current workspace. Numbered workspaces are matched by
-- number ("2"); named ones (negative id) need the "name:" selector.
local function set_workspace_layout(layout_name, label)
    local ws = hl.get_active_workspace()
    local selector = ws.name
    if not tostring(ws.name):match("^%d+$") then
        selector = "name:" .. ws.name
    end
    hl.workspace_rule({ workspace = selector, layout = layout_name })
    -- On-switch HUD via Hyprland's built-in notifications: <icon:-1=none> <ms> <color> <message>,
    -- in the accent of the desktop theme (appearance.lua)
    hl.dispatch(hl.dsp.exec_cmd("hyprctl notify -1 1200 '" .. (theme_accent or "rgb(7a9bf5)") .. "' 'fontsize:21  " .. label .. "'"))
end
local function layout(name, label)
    return function() set_workspace_layout(name, label) end
end

-- qs(): a menu entry that triggers a Quickshell shortcut. The entries run inside function
-- binds, so it goes through qs_send (keybindings.lua); qs_dsp() is the plain dispatcher, for
-- binds that are not functions.
local qs = function(name) return function() qs_send(name) end end
local qs_dsp = function(name) return hl.dsp.global("quickshell:" .. name) end
local S = mainMod .. " + "

-- Super+Esc: back to a clean screen, whatever is open
local function clean_screen()
    hl.dispatch(hl.dsp.submap("reset"))
    qs_send("whichkey-close")   -- qs_send, not qs(): see modules/keybindings.lua
    qs_send("notif-clean")
    qs_send("pickers-close")
    hl.dispatch(hl.dsp.exec_cmd([[pypr hide '*'; pkill tofi; pkill -x rofi; hyprctl dismissnotify]]))
end

-- Super+Del: workspace "agents" with the agent-deck web UI (rule in workspaces.lua), and back.
-- Its own Chromium profile, so it is a separate process the window rule can catch; checked via
-- hyprctl because pgrep -f would match this very shell. The token (agent-deck web on NetBird, ~/.nixos)
-- is read from its file at launch: ?token= sets agent-deck's cookie, nothing secret in the dotfiles.
local function agents_workspace()
    if hl.get_active_workspace().name == "agents" then
        hl.dispatch(hl.dsp.focus({ workspace = "previous_per_monitor" }))
        return
    end
    hl.dispatch(hl.dsp.focus({ workspace = "name:agents" }))
    hl.dispatch(hl.dsp.exec_cmd([[hyprctl clients | grep -q 'class: chrome-127\.0\.0\.1__' || chromium --user-data-dir=$HOME/.local/share/agent-deck/chromium --force-device-scale-factor=1.3 --app="http://127.0.0.1:8420/?token=$(cat ~/.config/agent-deck/web-token 2>/dev/null)"]]))
end

-- Not usable here: digits, j/k/l/slash, Up/Down (navigation_binds, they stay active with the
-- menu open) and Esc/Backspace (close and back in the menu).
menu = {
    { "App", {
        { "Terminale",            terminal,                                           S .. "Return" },
        { "Browser",              "chromium",                                         S .. "SHIFT + F" },
        { "Emacs",                "emacs",                                            S .. "SHIFT + E" },
        { "Appunti (cronologia)", qs("clipboard"),                                  S .. "V" },
        { "Registra chiamata",    "~/.local/bin/meet-rec toggle",                     S .. "SHIFT + R" },
        -- Invio scrive la password, Alt+1 utente+Tab+password, Alt+T copia il TOTP.
        -- Vault bloccato prima (chiede sempre la master password) e dopo: sbloccato solo durante la scelta
        { "Password",             "rbw lock; rofi-rbw --selector rofi; rbw lock",     S .. "P" },
        { "Server Borsini",       "~/.local/bin/rdp-borsini",                         S .. "B" },
        { "Agent Deck",           agents_workspace,                                   S .. "DELETE" },
        -- Super+Alt+D (dettatura diretta) è di hyprwhspr-rs
        { "Dettatura in Emacs",   "~/.config/hypr/scripts/dettatura-emacs.sh",        S .. "ALT + E" },
        -- di nuovo Super+Ctrl+W per uscire: submap "clean" in keybindings.lua
        { "VM Windows",           vm_enter,                                           S .. "CTRL + W" },
    } },
    { "Scratchpad", {
        { "Yazi del workspace", "~/.config/hypr/scripts/yazi-workspace.sh", S .. "A" },
        { "Yazi globale",       "pypr toggle yazi",   S .. "SHIFT + A" },
        { "Editor",             "pypr toggle editor", S .. "X" },
        { "Terminale",          "pypr toggle term",   S .. "I" },
        { "Calcolatrice",       "pypr toggle qalc",   S .. "C" },
    } },
    { "Finestre", {
        { "Cerca e apri",          qs("smart"),                S .. "S" },
        { "Exposé",                qs("expose"),               S .. "E" },
        { "Schermo intero",        hl.dsp.window.fullscreen(), S .. "F" },
        { "Chiudi finestra",       hl.dsp.window.close(),      S .. "Q" },
        { "Scambia i due monitor", "~/.config/hypr/scripts/swap_monitor_windows.sh", S .. "T" },
        -- ~/.local/bin/theme: widget, bordi, rofi, tofi, kitty e GTK insieme
        { "Tema", bind = S .. "SHIFT + T", group = {
            { "c", "Chiaro", "~/.local/bin/theme chiaro" },
            { "s", "Scuro",  "~/.local/bin/theme scuro" },
            { "n", "Nero",   "~/.local/bin/theme nero" },
        } },
        { "Layout del workspace", bind = S .. "SHIFT + L", group = {
            { "m", "Master",    layout("lua:custom_center2", "Master") },
            { "f", "Monocle",   layout("monocle",            "Monocle") },
            { "s", "Scrolling", layout("scrolling",          "Scrolling") },
            { "d", "Dwindle",   layout("dwindle",            "Dwindle") },
        } },
    } },
    { "Notifiche", {
        { "Riapri l'ultima",    qs("notif-pop"),       S .. "N" },
        { "Chiudi tutte",       qs("notif-close-all"), S .. "SHIFT + N" },
        { "Azione della prima", qs("notif-action"),    S .. "CTRL + N" },
        { "Cronologia",         qs("notif-history"),   S .. "ALT + N" },
        { "Non disturbare",     qs("notif-dnd"),       S .. "D" },
    } },
    { "Pomodoro", {
        { "Pomodoro", bind = S .. "O", group = {
            { "s", "Avvia",            qs("pomodoro-start") },
            { "p", "Pausa / riprendi", qs("pomodoro-pause") },
            { "n", "Salta la fase",    qs("pomodoro-skip") },
            { "x", "Ferma",            qs("pomodoro-stop") },
        } },
    } },
    { "Screenshot", {
        { "Area negli appunti", [[grim -g "$(slurp -d -c 00000000 -b 00000080)" - | wl-copy]], S .. "SHIFT + S" },
        { "Area temporanea",    "~/.config/hypr/scripts/temp_screenshot.sh",                  S .. "CTRL + SHIFT + S" },
        { "Area in inbox",      [[mkdir -p ~/inbox/screenshots && grim -g "$(slurp -d -c 00000000 -b 00000080)" ~/inbox/screenshots/"$(date +'%Y%m%dT%H%M%S')".png]], S .. "ALT + S" },
    } },
    { "Sessione", {
        { "Pulisci schermo",  clean_screen,  S .. "ESCAPE" },
        { "Esci da Hyprland", hl.dsp.exit(), S .. "SHIFT + Q" },
    } },
}

local function as_action(run)
    if type(run) == "string" then return hl.dsp.exec_cmd(run) end
    return run
end
local function run_action(run)
    run = as_action(run)
    if type(run) == "function" then run() else hl.dispatch(run) end
end

-- Called by the overlay: whichkey_run("3.9.1") = section 3, entry 9, chord key 1.
function whichkey_run(path)
    local idx = {}
    for i in path:gmatch("%d+") do idx[#idx + 1] = tonumber(i) end
    local it = menu[idx[1]][2][idx[2]]
    run_action(idx[3] and it.group[idx[3]][3] or it[2])
end

-- The key as the menu shows and matches it: modifiers in a fixed order, Super left out.
-- "SUPER + SHIFT + N" -> "Shift+N", "SUPER + Return" -> "Enter", "m" -> "M"
local function menu_key(bind)
    local names = { RETURN = "Enter", ESCAPE = "Esc", SPACE = "Space", DELETE = "Del" }
    local mods, key = {}, nil
    for p in bind:gmatch("[^+%s]+") do
        local u = p:upper()
        if u == "CTRL" or u == "ALT" or u == "SHIFT" then mods[u] = true
        elseif u ~= "SUPER" then key = names[u] or u end
    end
    local out = {}
    if mods.CTRL then out[#out + 1] = "Ctrl" end
    if mods.ALT then out[#out + 1] = "Alt" end
    if mods.SHIFT then out[#out + 1] = "Shift" end
    out[#out + 1] = key
    return table.concat(out, "+")
end

local function json_str(s)
    return '"' .. (s:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end)) .. '"'
end
local function json_item(key, label, path, extra)
    return '{"key":' .. json_str(key) .. ',"label":' .. json_str(label)
        .. ',"path":' .. json_str(path) .. (extra or "") .. "}"
end

-- Bind the shortcuts and build the JSON for the overlay in the same walk.
local sections = {}
for si, sec in ipairs(menu) do
    local items = {}
    for ei, it in ipairs(sec[2]) do
        local path = si .. "." .. ei
        if it.group then
            -- the chord's shortcut opens the menu on it (GlobalShortcut "whichkey-3-9" in the widget)
            hl.bind(it.bind, qs_dsp("whichkey-" .. path:gsub("%.", "-")))
            local children = {}
            for ci, ch in ipairs(it.group) do
                children[#children + 1] = json_item(menu_key(ch[1]), ch[2], path .. "." .. ci)
            end
            items[#items + 1] = json_item(menu_key(it.bind), it[1], path,
                ',"items":[' .. table.concat(children, ",") .. "]")
        else
            -- also tell the menu a shortcut fired: holding Super afterwards doesn't open it
            hl.bind(it[3], function() run_action(it[2]); qs_send("whichkey-cancel") end)
            items[#items + 1] = json_item(menu_key(it[3]), it[1], path)
        end
    end
    sections[#sections + 1] = '{"title":' .. json_str(sec[1]) .. ',"items":[' .. table.concat(items, ",") .. "]}"
end

-- Hold Super: the widget opens the menu after a moment and puts Hyprland in the
-- "whichkey" submap, where Super+key goes to the menu instead of the shortcuts above.
-- Quick combos never see it.
hl.bind(S .. "Super_L", qs_dsp("whichkey-hold"))   -- the widget gets both press and release

-- Esc leaves the submap even if the widget isn't there to do it
local function leave_menu()
    hl.dispatch(hl.dsp.submap("reset"))
    qs_send("whichkey-close")
end
hl.define_submap("whichkey", function()
    hl.bind("escape", leave_menu)
    hl.bind(S .. "escape", clean_screen)
    hl.bind(S .. "Super_L", qs_dsp("whichkey-hold"))
    -- workspaces, focus, volume and mouse keep working (and close the menu)
    navigation_binds(leave_menu)
end)

local f = io.open((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/whichkey.json", "w")
if f then
    f:write('{"sections":[' .. table.concat(sections, ",") .. "]}\n")
    f:close()
end
