-- Shared Pokemon-style battle presentation, used by the stage 2 Diogenis
-- encounter and the stage 3 cat rematch: strip-wipe transition, dusk battle
-- field, status panels, and the 2x2 choice menu.
local BV = {}

local CW, CH   = 320, 180
local N_STRIPS = 12
local STRIP_H  = math.ceil(CH / N_STRIPS) + 1

local function easeOut(t) return 1 - (1-t)*(1-t) end
BV.easeOut = easeOut

-- Alternating strip wipe; t goes 0 (open) -> 1 (fully covered).
-- Even strips use opts.c1 until t=0.85, then everything is opts.c2
-- (defaults: white flashing to black). opts.reverse flips the slide
-- direction for the "heroic" version of the wipe.
function BV.drawStrips(t, opts)
    opts = opts or {}
    local c1 = opts.c1 or {1, 1, 1}
    local c2 = opts.c2 or {0, 0, 0}
    for i = 0, N_STRIPS - 1 do
        local fromRight = i % 2 == 1
        if opts.reverse then fromRight = not fromRight end
        -- stagger each strip slightly so they don't all arrive at once
        local delay = (i / N_STRIPS) * 0.25
        local prog  = math.max(0, math.min(1, (t - delay) * (1 + delay)))
        local w = easeOut(prog) * CW
        local c = (t < 0.85 and i % 2 == 0) and c1 or c2
        love.graphics.setColor(c[1], c[2], c[3])
        love.graphics.rectangle("fill", fromRight and (CW - w) or 0, i * STRIP_H, w, STRIP_H)
    end
end

-- Dusk battle-field backdrop: sky gradient, clouds, ground band and the
-- two glowing trainer platforms (player near-left, enemy far-right).
function BV.drawField()
    local steps = 6
    for i = 0, steps - 1 do
        local t = i / (steps - 1)
        love.graphics.setColor(0.16 + 0.12*(1-t), 0.22 + 0.18*(1-t), 0.38 + 0.20*(1-t))
        love.graphics.rectangle("fill", 0, (90/steps)*i, CW, 90/steps + 1)
    end
    love.graphics.setColor(1, 1, 1, 0.12)
    for _, cx in ipairs({60, 150, 230, 300}) do
        love.graphics.ellipse("fill", cx, 26, 20, 6)
    end
    love.graphics.setColor(0.30, 0.34, 0.26)
    love.graphics.rectangle("fill", 0, 90, CW, CH - 90)
    love.graphics.setColor(0.85, 0.80, 0.55, 0.5)
    love.graphics.rectangle("fill", 0, 89, CW, 2)
    love.graphics.setColor(0.50, 0.55, 0.45)
    love.graphics.rectangle("fill", 0, 91, CW, 4)
    -- Player platform (left, near) with soft glow ring
    love.graphics.setColor(1, 1, 0.85, 0.10)
    love.graphics.ellipse("fill", 68, 128, 46, 14)
    love.graphics.setColor(0.45, 0.50, 0.40)
    love.graphics.ellipse("fill", 68, 128, 38, 10)
    love.graphics.setColor(0.35, 0.40, 0.30)
    love.graphics.ellipse("line", 68, 128, 38, 10)
    -- Enemy platform (right, far)
    love.graphics.setColor(1, 0.85, 0.85, 0.10)
    love.graphics.ellipse("fill", 248, 72, 34, 10)
    love.graphics.setColor(0.45, 0.50, 0.40)
    love.graphics.ellipse("fill", 248, 72, 28, 7)
    love.graphics.setColor(0.35, 0.40, 0.30)
    love.graphics.ellipse("line", 248, 72, 28, 7)
end

-- Enemy status panel (top-left): label plus a meter filled to `pct` (0..1)
-- in `fillColor`. Pass pct = 0 for a permanently empty bar.
function BV.drawEnemyPanel(label, pct, fillColor, font)
    love.graphics.setColor(0.92, 0.90, 0.85)
    love.graphics.rectangle("fill", 8, 8, 142, 36)
    love.graphics.setColor(0.20, 0.20, 0.20)
    love.graphics.rectangle("line", 8, 8, 142, 36)
    love.graphics.setColor(0.10, 0.10, 0.10)
    if font then love.graphics.setFont(font) end
    love.graphics.print(label, 13, 12)
    love.graphics.setColor(0.50, 0.50, 0.50)
    love.graphics.rectangle("fill", 13, 26, 128, 9)
    if pct and pct > 0 and fillColor then
        love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3])
        love.graphics.rectangle("fill", 13, 26, 128 * math.min(1, pct), 9)
    end
    love.graphics.setColor(0.20, 0.20, 0.20)
    love.graphics.rectangle("line", 13, 26, 128, 9)
end

-- Player status panel (bottom-left, Pokemon style)
function BV.drawPlayerPanel(font)
    love.graphics.setColor(0.92, 0.90, 0.85)
    love.graphics.rectangle("fill", 8, 128, 120, 22)
    love.graphics.setColor(0.20, 0.20, 0.20)
    love.graphics.rectangle("line", 8, 128, 120, 22)
    if font then love.graphics.setFont(font) end
    love.graphics.setColor(0.10, 0.10, 0.10)
    love.graphics.print("YOU  Lv.BIRTHDAY", 12, 131)
    love.graphics.setColor(0.10, 0.75, 0.20)
    love.graphics.rectangle("fill", 12, 142, 110, 5)
    love.graphics.setColor(0.20, 0.20, 0.20)
    love.graphics.rectangle("line", 12, 142, 110, 5)
end

-- Bottom text box: question on the left half, 2x2 choice grid on the right.
-- Optional hint line: pass showHint=true to reveal `hint`, false to show the
-- "[H] Hint" prompt, nil for no hint UI at all (the cat offers no hints).
function BV.drawMenu(question, choices, selIdx, font, hint, showHint)
    love.graphics.setColor(0.92, 0.90, 0.85)
    love.graphics.rectangle("fill", 0, 148, CW, CH - 148)
    love.graphics.setColor(0.20, 0.20, 0.20)
    love.graphics.rectangle("line", 0, 148, CW, CH - 148)
    love.graphics.line(CW/2, 148, CW/2, CH)

    if font then love.graphics.setFont(font) end
    love.graphics.setColor(0.10, 0.10, 0.10)
    love.graphics.printf(question, 6, 152, CW/2 - 10, "left")

    local cells = {
        {x=CW/2+4,  y=152}, {x=CW/2+82, y=152},
        {x=CW/2+4,  y=163}, {x=CW/2+82, y=163},
    }
    for i, cell in ipairs(cells) do
        local ch = choices[i]
        if ch then
            if i == selIdx then
                love.graphics.setColor(0.10, 0.10, 0.10)
                love.graphics.print("> " .. ch.label, cell.x, cell.y)
            else
                love.graphics.setColor(0.40, 0.40, 0.40)
                love.graphics.print(ch.label, cell.x + 6, cell.y)
            end
        end
    end

    if showHint and hint then
        love.graphics.setColor(0.20, 0.55, 0.20)
        love.graphics.printf(hint, 4, CH - 10, CW - 8, "left")
    elseif showHint == false then
        love.graphics.setColor(0.50, 0.50, 0.50)
        love.graphics.print("[H] Hint", CW - 42, CH - 10)
    end
end

-- Arrow-key navigation over the 2x2 menu grid; returns the new selection.
-- Grid order: 1=top-left 2=top-right 3=bottom-left 4=bottom-right.
function BV.navMenu(sel, key, n)
    if key == "left"  and sel % 2 == 0 then sel = sel - 1 end
    if key == "right" and sel % 2 == 1 then sel = math.min(sel + 1, n) end
    if key == "up"    and sel > 2      then sel = sel - 2 end
    if key == "down"  and sel <= 2     then sel = math.min(sel + 2, n) end
    return sel
end

return BV
