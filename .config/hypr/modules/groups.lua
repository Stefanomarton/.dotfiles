----------------
---- GROUPS ----
----------------

-- Gruppi (finestre a schede). Super+G (group_smart): in un gruppo lo blocca o sblocca (bloccato
-- non entra più niente); fuori entra nel gruppo del workspace, o ne crea uno.
-- Super+Shift+G (group_dissolve) scompone il gruppo: tutte le finestre tornano carte.
-- Super+l/k scorrono le schede (nav_focus in keybindings.lua). Le finestre nuove si aprono nel
-- gruppo che ha il focus (auto_group). Colori della barra: apply_theme() in appearance.lua.
-- Layout master: la pila diventa un gruppo per lato (stack_normalize, in fondo).
hl.config({
    group = {
        auto_group           = true,
        drag_into_group      = 2,      -- si entra trascinando solo sulla barra, mai sulla finestra
        merge_groups_on_drag = false,
        -- Schede piene senza gradients (costano ~130 ms a ogni gruppo creato o finestra aggiunta:
        -- Hyprland ridisegna 4 texture grandi quanto il monitor). Lo sfondo della scheda è
        -- l'indicatore, un rettangolo semplice alto quanto la scheda; la barra del titolo è alta
        -- 1 px e text_offset porta il titolo dentro l'indicatore.
        groupbar = {
            font_family          = "JuliaMono",
            font_size            = profile.laptop and 12 or 14,
            gradients            = false,
            height               = 1,
            indicator_gap        = 0,
            indicator_height     = profile.laptop and 20 or 24,
            text_offset          = profile.laptop and -10 or -12,
            font_weight_active   = "bold",
            font_weight_inactive = "normal",
            rounding             = 4,
            gaps_in              = 0,      -- schede attaccate: con lo spazio in mezzo si vedeva una lineetta dello sfondo
            round_only_edges     = true,   -- arrotondati solo i due estremi della barra
            middle_click_close   = true,
            scrolling            = true,   -- rotella sulla barra = scheda accanto
        },
    },
})

local function addr(w) return "address:" .. w.address end

-- in 0.56 group.lock ignora action e inverte sempre: si chiama solo se lo stato è diverso
local function set_lock(w, want)
    local g = hl.get_window(addr(w)).group
    if g and g.locked ~= want then hl.dispatch(hl.dsp.group.lock({ window = addr(w) })) end
end

-- il gruppo non bloccato del workspace di w usato più di recente
local function workspace_group(w)
    local best
    for _, o in ipairs(hl.get_windows()) do
        if o.address ~= w.address and o.group and not o.group.locked and not o.floating
            and o.workspace and w.workspace and o.workspace.id == w.workspace.id
            and (not best or o.focus_history_id < best.focus_history_id) then
            best = o
        end
    end
    return best
end

function group_smart(w)
    w = w or hl.get_active_window()
    if not w then return end
    if w.group then
        set_lock(w, not w.group.locked)
        return
    end
    local host = workspace_group(w)
    if host then
        host.group:add(w)
        hl.dispatch(hl.dsp.focus({ window = addr(w) }))
    else
        hl.dispatch(hl.dsp.group.toggle({ window = addr(w) }))
    end
end

function group_dissolve(w)
    w = w or hl.get_active_window()
    if w and w.group then hl.dispatch(hl.dsp.group.toggle({ window = addr(w) })) end
end

-- App di messaggi: sempre in un solo gruppo bloccato. Pattern Lua sulla classe; le finestre-app
-- di Chromium del test in ~/.local/share/msg-test hanno la classe chrome-<url>-msg-<account>.
local MESSAGING = { "^chrome%-.*%-msg%-", "^teams%-for%-linux$" }

local function is_msg(w)
    if not w or w.floating then return false end
    for _, p in ipairs(MESSAGING) do
        if (w.class or ""):match(p) then return true end
    end
    return false
end

-- il lock blocca anche group:add, quindi: sblocca, aggiungi, riblocca
local busy = false
local function regroup()
    if busy then return end
    busy = true
    pcall(function()
        local wins, host = {}, nil
        for _, w in ipairs(hl.get_windows()) do
            if is_msg(w) then
                wins[#wins + 1] = w
                if w.group and (not host or w.group.size > host.group.size) then host = w end
            end
        end
        if #wins == 0 then return end
        if host and host.group.locked and host.group.size == #wins then return end -- già a posto
        if not host then
            hl.dispatch(hl.dsp.group.toggle({ window = addr(wins[1]) }))
            host = hl.get_window(addr(wins[1]))
        end
        local g = tostring(host.group)
        set_lock(host, false)
        for _, w in ipairs(wins) do
            if tostring(w.group) ~= g then pcall(function() hl.get_window(addr(host)).group:add(w) end) end
        end
        set_lock(host, true)
    end)
    busy = false
end

-- finestra nuova, spostata in un altro workspace o tirata fuori: torna nel gruppo.
-- window.class: all'apertura Chromium non ha ancora la classe
for _, ev in ipairs({ "window.open", "window.class", "window.move_to_workspace", "window.active" }) do
    hl.on(ev, function(w) if is_msg(w) then regroup() end end)
end


-- Pila del master come gruppi: oltre la master al massimo un'unità (finestra o gruppo) per lato,
-- due sui monitor larghi (master al centro) e una sul pannello del portatile (master a sinistra).
-- Una finestra in più finisce nel gruppo del suo lato; quando le finestre calano, i gruppi fatti
-- così si sciolgono (sul G9: fino a 3 finestre master al centro senza gruppi). Se la master diventa un gruppo (chiusa la
-- master, ne prende il posto la pila), la sua scheda visibile esce e torna master.
-- Esclusi: finestre flottanti (popup, dialoghi), gruppi bloccati, app di messaggi, finestre
-- ancora senza classe (Chromium all'apertura), workspace non master.
function stack_slots(w)
    return (w.monitor and w.monitor.name:match("^eDP")) and 1 or 2
end

local function xpos(w) return type(w.at) == "table" and (w.at.x or w.at[1]) or 0 end

-- unità tiled del workspace: { win = finestra visibile, group, master, x }
local function stack_units(ws_id)
    local units, by = {}, {}
    for _, w in ipairs(hl.get_windows()) do
        if w.workspace and w.workspace.id == ws_id and not w.floating then
            local key = w.group and tostring(w.group) or w.address
            local u = by[key]
            if not u then
                u = { win = w, group = w.group }
                by[key] = u
                units[#units + 1] = u
            end
            if w.layout and w.layout.is_master then u.master = true end
            if not w.group or (w.group.current and w.group.current.address == w.address) then u.win = w end
        end
    end
    for _, u in ipairs(units) do u.x = xpos(u.win) end
    return units
end

-- finestre messe in gruppo da stack_normalize: solo quei gruppi si sciolgono da soli
-- (non quelli fatti con Super+G)
stack_auto = stack_auto or {}
local function auto_grouped(g)
    if not g or g.locked then return false end
    for _, m in ipairs(g.members or {}) do
        if not stack_auto[m.address] then return false end
    end
    return true
end

local function foldable(u)
    return not u.master and not u.group and (u.win.class or "") ~= "" and not is_msg(u.win)
end

-- w esce dal suo gruppo (se sbloccato) e prende il posto della master del suo workspace
local function to_master(w)
    w = hl.get_window(addr(w))
    if not w or w.floating or not w.workspace or w.workspace.tiled_layout ~= "master" then return end
    if w.group and w.group.size > 1 and not w.group.locked then
        -- group:remove, non move out_of_group: quello dà sempre il focus (cambierebbe workspace)
        pcall(function() w.group:remove(w) end)
        w = hl.get_window(addr(w))
    end
    if w.layout and w.layout.is_master then return end
    for _, m in ipairs(hl.get_windows()) do
        if m.address ~= w.address and m.workspace and m.workspace.id == w.workspace.id
            and m.layout and m.layout.is_master then
            hl.dispatch(hl.dsp.window.swap({ window = addr(w), target = addr(m) }))
            break
        end
    end
end

local function stack_normalize_ws(ws_id)
    for _ = 1, 6 do   -- una mossa per giro, poi si rilegge lo stato
        local units = stack_units(ws_id)
        local master
        for _, u in ipairs(units) do if u.master then master = u end end
        if not master then return end
        if master.group and master.group.size > 1 and not master.group.locked then
            to_master(master.win)
        else
            local slaves = {}
            for _, u in ipairs(units) do if not u.master then slaves[#slaves + 1] = u end end
            local slots = stack_slots(master.win)
            if #slaves <= slots then
                -- meno finestre: un gruppo fatto da qui si scioglie se le sue finestre ci stanno da sole
                -- (uno per giro: chiudendone due di fila restano due gruppi da una scheda)
                local dissolved
                for _, u in ipairs(slaves) do
                    if auto_grouped(u.group) and #slaves - 1 + u.group.size <= slots then
                        for _, m in ipairs(u.group.members) do stack_auto[m.address] = nil end
                        hl.dispatch(hl.dsp.group.toggle({ window = addr(u.win) }))
                        dissolved = true
                        break
                    end
                end
                if not dissolved then return end
            end
            -- la finestra sola usata più di recente (di solito quella appena aperta)
            local lone
            for _, u in ipairs(slaves) do
                if foldable(u) and (not lone or u.win.focus_history_id < lone.win.focus_history_id) then lone = u end
            end
            if not lone then return end
            -- destinazione: stesso lato della master, meglio un gruppo, poi la più piccola
            local left, target, best = lone.x < master.x, nil, nil
            for _, u in ipairs(slaves) do
                if u ~= lone and not (u.group and u.group.locked) and not is_msg(u.win) then
                    local score = ((u.x < master.x) == left and 0 or 100) + (u.group and 0 or 10)
                        + (u.group and u.group.size or 1)
                    if not best or score < best then target, best = u, score end
                end
            end
            if not target then return end
            if not target.group then
                hl.dispatch(hl.dsp.group.toggle({ window = addr(target.win) }))
            end
            pcall(function() hl.get_window(addr(target.win)).group:add(lone.win) end)
            if not target.group then stack_auto[target.win.address] = true end
            stack_auto[lone.win.address] = true
            if lone.win.active then hl.dispatch(hl.dsp.focus({ window = addr(lone.win) })) end
        end
    end
end

function stack_normalize()
    local seen = {}
    for _, w in ipairs(hl.get_windows()) do
        local ws = w.workspace
        if ws and ws.id and not seen[ws.id] and ws.tiled_layout == "master" then
            seen[ws.id] = true
            stack_normalize_ws(ws.id)
        end
    end
end

-- apertura: subito, nell'evento (il layout ha già messo la finestra: niente attese, il gruppo si
-- forma prima del frame successivo). Chiusura e spostamento: nell'evento il layout non è ancora
-- aggiornato (la finestra spostata risulta ancora master del workspace di prima), quindi un attimo dopo.
for _, ev in ipairs({ "window.open", "window.class" }) do
    hl.on(ev, function() pcall(stack_normalize) end)
end
local stack_timer, new_master
local function stack_later()
    if stack_timer then stack_timer:set_enabled(false) end
    stack_timer = hl.timer(function()
        if new_master then pcall(to_master, new_master); new_master = nil end
        pcall(stack_normalize)
    end, { timeout = 30, type = "oneshot" })
end
-- chiudendone più di fila, quella che sta chiudendo può essere ancora nel gruppo dopo 30 ms:
-- un secondo giro a animazione finita (normalizzare due volte non cambia niente)
hl.on("window.close", function()
    stack_later()
    hl.timer(function() pcall(stack_normalize) end, { timeout = 400, type = "oneshot" })
end)
hl.on("window.move_to_workspace", stack_later)

-- Super+S, Ctrl+Invio su una finestra (SmartPickerManager.qml): la porta nel workspace corrente
-- e ne fa la master. ws (solo per le prove): un altro workspace, senza focus
function bring_master(address, ws)
    local w = hl.get_window("address:" .. address)
    if not w then return end
    if not w.floating then new_master = w end
    hl.dispatch(hl.dsp.window.move({ workspace = ws or "e+0", window = addr(w), follow = false }))
    if not ws then hl.dispatch(hl.dsp.focus({ window = addr(w) })) end
    stack_later()   -- se era già qui non c'è l'evento
end
