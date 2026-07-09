-- Procedural pixel-art sprite drawing utilities
local S = {}

local function px(r,g,b) return {r,g,b} end

-- Draw a pixel-grid sprite.
-- grid:    2D array of colour-index values (0 = transparent)
-- pal:     array of {r,g,b} tables (1-indexed)
-- x,y:     top-left canvas position
-- ps:      pixel size in canvas pixels
-- outline: if not false, draws a 1px dark silhouette behind the sprite
--          so it reads cleanly against busy backgrounds
function S.grid(grid, pal, x, y, ps, outline)
    ps = ps or 2
    if outline ~= false then
        love.graphics.setColor(0.08, 0.06, 0.10, 0.85)
        for row = 1, #grid do
            for col = 1, #grid[row] do
                if grid[row][col] > 0 then
                    local px0 = x + (col-1)*ps
                    local py0 = y + (row-1)*ps
                    love.graphics.rectangle("fill", px0-1, py0-1, ps+2, ps+2)
                end
            end
        end
    end
    for row = 1, #grid do
        for col = 1, #grid[row] do
            local ci = grid[row][col]
            if ci > 0 and pal[ci] then
                local c = pal[ci]
                love.graphics.setColor(c[1], c[2], c[3])
                love.graphics.rectangle("fill",
                    x + (col-1)*ps, y + (row-1)*ps, ps, ps)
            end
        end
    end
    love.graphics.setColor(1,1,1)
end

-- Soft grounding shadow drawn under a character/object before its sprite.
function S.shadow(cx, groundY, w)
    w = w or 16
    love.graphics.setColor(0, 0, 0, 0.28)
    love.graphics.ellipse("fill", cx, groundY, w/2, w/5)
    love.graphics.setColor(1,1,1)
end

-- ── PLAYER (irida) ── IridaSprite.png sheet, 21×34 frames ──────────────────
-- The sheet is a 9×9 grid (2px gutters, 23×36 cell stride): each row is one
-- facing direction (S, SE, E, NE, N, NW, W, SW, S) with a 9-frame walk cycle.
local PLAYER_IMG = love.graphics.newImage("assets/sprites/characters/IridaSprite.png")
local PFW, PFH = 21, 34
local PLAYER_ROW = { down = 0, right = 2, up = 4, left = 6 }
local PLAYER_QUADS = {}
for dir, row in pairs(PLAYER_ROW) do
    PLAYER_QUADS[dir] = {}
    for frame = 0, 8 do
        PLAYER_QUADS[dir][frame + 1] = love.graphics.newQuad(
            2 + frame * 23, 2 + row * 36, PFW, PFH,
            PLAYER_IMG:getDimensions())
    end
end

-- dir: "down"/"up"/"left"/"right" (default "down")
-- moving: when true, plays the walk cycle; otherwise the standing frame
-- (x,y) is the top-left of the 16×20 logical box the stages use for bounds
-- and proximity checks; the 21×34 art is offset so her feet sit on its floor.
function S.drawPlayer(x, y, dir, moving)
    local quads = PLAYER_QUADS[dir] or PLAYER_QUADS.down
    local frame = 1
    if moving then
        frame = 2 + math.floor(love.timer.getTime() * 10) % 8
    end
    S.shadow(x + 8, y + 19, 14)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(PLAYER_IMG, quads[frame], x - 3, y - 14)
end
S.playerW, S.playerH = 16, 20

-- ── INSTRUCTOR ── instructor.png sheet ─────────────────────────────────────
-- Single row of ten 140×140 cells (10-frame idle, one facing direction);
-- the character occupies roughly x 57..89, y 44..96 of its cell.
local INST_IMG = love.graphics.newImage("assets/sprites/characters/instructor.png")
local INST_QUADS = {}
for frame = 0, 9 do
    INST_QUADS[frame + 1] = love.graphics.newQuad(
        frame * 140, 0, 140, 140, INST_IMG:getDimensions())
end

-- (x,y) is the top-left of the same 16×20 logical box the old pixel-grid
-- sprite used; the cell is offset so the feet sit on the box floor.
function S.drawInstructor(x, y)
    local frame = 1 + math.floor(love.timer.getTime() * 8) % 10
    S.shadow(x+8, y+19, 14)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(INST_IMG, INST_QUADS[frame], x - 65, y - 77)
end

-- ── DIOGENIS (strict dad) ── Diogenis_Idle.png sheet ───────────────────────
-- 4×4 grid of 64×64 cells: each row is a facing direction (down, up, left,
-- right) with a 4-frame idle. The character occupies x 20..42, y 17..46.
local DAD_IMG = love.graphics.newImage("assets/sprites/characters/Diogenis_Idle.png")
local DAD_ROW = { down = 0, up = 1, left = 2, right = 3 }
local DAD_QUADS = {}
for dir, row in pairs(DAD_ROW) do
    DAD_QUADS[dir] = {}
    for frame = 0, 3 do
        DAD_QUADS[dir][frame + 1] = love.graphics.newQuad(
            frame * 64, row * 64, 64, 64, DAD_IMG:getDimensions())
    end
end

-- (x,y) is the top-left of the same 16×20 logical box the old pixel-grid
-- sprite used; the cell is offset so his feet sit on the box floor.
-- dir: "down"/"up"/"left"/"right" (default "down")
function S.drawDiogenis(x, y, dir)
    local quads = DAD_QUADS[dir] or DAD_QUADS.down
    local frame = 1 + math.floor(love.timer.getTime() * 5) % 4
    S.shadow(x+8, y+19, 14)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(DAD_IMG, quads[frame], x - 23, y - 27)
end

-- ── ROMANOS (charming friend) ── romanosSprite.png sheet ───────────────────
-- Animation sheet on a 9×5 grid of 60×46 cells; the first row is a 5-frame
-- front-facing idle. The character occupies x 21..37, y 8..41 of its cell.
local ROM_IMG = love.graphics.newImage("assets/sprites/characters/romanosSprite.png")
local ROM_QUADS = {}
for frame = 0, 4 do
    ROM_QUADS[frame + 1] = love.graphics.newQuad(
        frame * 60, 0, 60, 46, ROM_IMG:getDimensions())
end

-- (x,y) is the top-left of the same 16×20 logical box the old pixel-grid
-- sprite used; the cell is offset so his feet sit on the box floor and the
-- idle animation plays continuously.
function S.drawRomanos(x,y)
    local frame = 1 + math.floor(love.timer.getTime() * 6) % 5
    S.shadow(x+8, y+19, 14)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(ROM_IMG, ROM_QUADS[frame], x - 21, y - 22)
end

-- ── MARKOULINOS (boyfriend) ── markoulinos_sprite.png sheet ────────────────
-- Irregularly packed 736×687 sheet; only the symmetric front-facing frame
-- at x 189..309, y 36..228 is used, drawn as a static pose.
local MARK_IMG  = love.graphics.newImage("assets/sprites/characters/markoulinos_sprite.png")
local MARK_QUAD = love.graphics.newQuad(189, 36, 121, 193, MARK_IMG:getDimensions())
local MARK_SCALE = 0.2   -- ~24×39 on canvas, a touch taller than the player

-- (x,y) is the top-left of the same 16×20 logical box the other characters
-- use; the frame is scaled down and anchored so his feet sit on the box
-- floor, centred.
function S.drawMarkoulinos(x, y)
    S.shadow(x+8, y+19, 14)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(MARK_IMG, MARK_QUAD,
        x + 8 - 121*MARK_SCALE/2, y + 20 - 193*MARK_SCALE,
        0, MARK_SCALE, MARK_SCALE)
end

-- ── CAT ── IdleCatb.png (7-frame idle) + JumpCabt.png (13-frame leap) ──────
-- Both sheets are single rows of 32×32 cells, cat facing right; idle content
-- sits at y 8..29 of its cell.
local CAT_IDLE_IMG = love.graphics.newImage("assets/sprites/characters/IdleCatb.png")
local CAT_JUMP_IMG = love.graphics.newImage("assets/sprites/characters/JumpCabt.png")
local CAT_IDLE_QUADS, CAT_JUMP_QUADS = {}, {}
for frame = 0, 6 do
    CAT_IDLE_QUADS[frame + 1] = love.graphics.newQuad(
        frame * 32, 0, 32, 32, CAT_IDLE_IMG:getDimensions())
end
for frame = 0, 12 do
    CAT_JUMP_QUADS[frame + 1] = love.graphics.newQuad(
        frame * 32, 0, 32, 32, CAT_JUMP_IMG:getDimensions())
end

-- (x,y) is the top-left of the same 16×16 logical box the old pixel-grid
-- sprite used. jumping: plays the leap cycle (for the kitchen dash).
function S.drawCat(x, y, jumping)
    local img, quads, frame
    if jumping then
        img, quads = CAT_JUMP_IMG, CAT_JUMP_QUADS
        frame = 1 + math.floor(love.timer.getTime() * 14) % 13
    else
        img, quads = CAT_IDLE_IMG, CAT_IDLE_QUADS
        frame = 1 + math.floor(love.timer.getTime() * 6) % 7
    end
    S.shadow(x+8, y+15, 14)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(img, quads[frame], x - 8, y - 14)
end
S.catW, S.catH = 16, 16

-- ── CAKE ── birthday_cake.png, 100×100 file ────────────────────────────────
-- The cake art occupies x 23..78, y 4..88 of the file; drawn at 0.35 scale
-- it is ~20px wide, centred on the same 20×24 logical box the old
-- pixel-grid sprite used, with the plate resting on the box floor.
local CAKE_IMG   = love.graphics.newImage("assets/sprites/items/birthday_cake.png")
local CAKE_SCALE = 0.35
function S.drawCake(x,y)
    S.shadow(x+10, y+24, 22)
    -- candle glow at the top of the cake
    love.graphics.setColor(1, 0.85, 0.35, 0.22)
    love.graphics.circle("fill", x+10, y-4, 8)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(CAKE_IMG,
        x + 10 - 50.5*CAKE_SCALE,   -- content centre → box centre
        y + 24 - 89*CAKE_SCALE,     -- content bottom → box floor
        0, CAKE_SCALE, CAKE_SCALE)
end
S.cakeW, S.cakeH = 20, 24

-- ── COOKIE ── 6×6 at ps=2 ──────────────────────────────────────────────────
local COOKIE_G = {
    {0,1,1,1,1,0},
    {1,1,2,1,1,1},
    {1,2,1,1,2,1},
    {1,1,1,2,1,1},
    {1,1,2,1,1,1},
    {0,1,1,1,1,0},
}
local COOKIE_P = {
    px(0.85,0.60,0.28), -- 1 cookie
    px(0.38,0.20,0.05), -- 2 choc chip
}
function S.drawCookie(x,y)
    S.shadow(x+6, y+11, 10)
    S.grid(COOKIE_G, COOKIE_P, x, y, 2)
end
S.cookieW, S.cookieH = 12, 12

-- ── CAR ── Miami-synth sprites, 184×68, faces left ─────────────────────────
-- car1.png parked; running/car-running1..5.png while driving (wheel spin +
-- body bob). The art includes its own ground shadow.
local CAR_IDLE_IMG = love.graphics.newImage("assets/sprites/environment/Miami-synth-files/sprites/car1.png")
local CAR_RUN_IMGS = {}
for i = 1, 5 do
    CAR_RUN_IMGS[i] = love.graphics.newImage(
        "assets/sprites/environment/Miami-synth-files/sprites/running/car-running"..i..".png")
end

-- driving: plays the running animation (wheels spinning)
function S.drawCar(x, y, driving)
    love.graphics.setColor(1,1,1)
    if driving then
        local img = CAR_RUN_IMGS[1 + math.floor(love.timer.getTime() * 16) % 5]
        love.graphics.draw(img, x, y)
    else
        love.graphics.draw(CAR_IDLE_IMG, x, y)
    end
end
S.carW, S.carH = 184, 68

return S
