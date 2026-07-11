-----------------
---- LAYOUTS ----
-----------------

-- Centered master with cascaded, overlapping side decks.
-- NOTE: side windows overlap on purpose; with follow_mouse = 1 (hover focus)
-- the overlap region focuses whichever window sits underneath.
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
            -- 3+ windows: centered master with cascaded side decks.
            local master_ratio = 0.5
            local master_w = math.floor(ctx.area.w * master_ratio)
            local side_w = math.floor((ctx.area.w - master_w) / 2)

            local left_count = math.ceil((n - 1) / 2)
            local right_count = math.floor((n - 1) / 2)

            local offset_step = 35 -- pixels to shift each window down and right

            -- Left stack (cascading down and right)
            if left_count > 0 then
                local total_offset = (left_count - 1) * offset_step
                local cascade_win_w = side_w - total_offset
                local cascade_win_h = math.floor(ctx.area.h) - total_offset

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

            -- Master window (target 1, centered)
            ctx.targets[1]:place({
                x = math.floor(ctx.area.x + side_w),
                y = math.floor(ctx.area.y),
                w = master_w,
                h = math.floor(ctx.area.h)
            })

            -- Right stack (cascading down and right)
            if right_count > 0 then
                local total_offset = (right_count - 1) * offset_step
                local cascade_win_w = side_w - total_offset
                local cascade_win_h = math.floor(ctx.area.h) - total_offset

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
