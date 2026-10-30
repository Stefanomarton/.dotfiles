-----------------
---- LAYOUTS ----
-----------------

-- Built-in layout engine tuning
-- https://wiki.hypr.land/Configuring/Dwindle-Layout/
hl.config({
    dwindle = {
        preserve_split = true,
    },
})

-- https://wiki.hypr.land/Configuring/Master-Layout/
hl.config({
    master = {
        new_status            = "slave",
        orientation           = "center",
        focus_master_on_close = true,
        mfact                 = 0.45,
    },
})

-- https://wiki.hypr.land/Configuring/Scrolling-Layout/
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
        column_width             = 0.35,
        focus_fit_method         = 1,
        follow_focus             = true,
        follow_min_visible       = 0.5,
    },
})

-- Monitor larghi (G9, Xiaomi), workspace 1-9: una finestra sola al centro, due con un margine ai
-- lati (px per lato). Sul pannello del portatile a tutta larghezza. w[tv1] = una finestra tiled visibile.
for m, margins in pairs({ [screens.main] = { 900, 500 }, [screens.side] = { 900, 200 } }) do
    for n, side in ipairs(margins) do
        hl.workspace_rule({
            workspace = "r[1-9] w[tv" .. n .. "] m[" .. m .. "]",
            gaps_out  = { top = 20, bottom = 20, left = side, right = side },
        })
    end
end
