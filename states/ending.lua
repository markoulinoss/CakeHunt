-- Ending: cake reveal, sweet message, credits, cookie bonus
local Transition   = require "systems.transition"
local Collectibles = require "systems.collectibles"
local Dialogue     = require "systems.dialogue"
local Sprites      = require "assets.sprites"
local Movement     = require "systems.movement"

local Ending = {}
Ending.__index = Ending

local CW, CH = 320, 180

-- Kitchen art for the post-credits chase (same quads as stage 3)
local FLOOR_IMG  = love.graphics.newImage("assets/Floor.png")
local WALL_IMG   = love.graphics.newImage("assets/walls.png")
local FLOOR_Q    = love.graphics.newQuad(49,  5, 45, 36, FLOOR_IMG:getDimensions())
local WALL_TOP_Q = love.graphics.newQuad(112,  5, 48, 32, WALL_IMG:getDimensions())
local WALL_BOT_Q = love.graphics.newQuad(112, 21, 48, 34, WALL_IMG:getDimensions())

local CHASE_TIME = 15
local CHASE_BOUND = {x=14, y=70, x2=CW-30, y2=CH-34}

-- Cat AI escape points: she runs to whichever is farthest from the player
local WAYPOINTS = {{40,84},{280,84},{40,140},{280,140},{160,112}}
local function farthestWaypoint(px, py)
    local best, bd = WAYPOINTS[1], -1
    for _, p in ipairs(WAYPOINTS) do
        local d = (p[1]-px)^2 + (p[2]-py)^2
        if d > bd then bd, best = d, p end
    end
    return best
end

function Ending.new(sm, audio, font)
    local s   = setmetatable({}, Ending)
    s.sm      = sm
    s.audio   = audio
    s.font    = font
    s.trans   = Transition.new()
    s.t       = 0
    s.phase   = "cake"   -- cake|message|bonus|credits
    s.pageT   = 0
    s.stars   = {}
    for i = 1, 50 do
        s.stars[i] = {
            x = love.math.random(CW), y = love.math.random(CH),
            r = love.math.random()*1.2 + 0.3,
            phase = love.math.random() * math.pi * 2,
        }
    end
    return s
end

function Ending:enter()
    self.phase = "cake"
    self.t     = 0
    self.pageT = 0
    self.audio.play("ending")
    self.audio.sfxPlay("reveal")
    self.trans:fadeIn(1.0)
end

function Ending:exit() end

function Ending:_startChase()
    self.phase   = "chase"
    self.pageT   = 0
    self.px, self.py     = 40, 110
    self.pdir, self.pmoving = "right", false
    self.keys    = {}
    self.cx, self.cy     = 250, 95
    self.catTarget       = nil
    self.catRunT         = 0
    self.catPaused       = false
    self.chaseT  = CHASE_TIME
    self.caught  = false
    self.audio.play("kitchen_music")
end

function Ending:update(dt)
    self.trans:update(dt)
    self.t     = self.t     + dt
    self.pageT = self.pageT + dt

    if self.phase ~= "chase" then return end

    -- ── Player ────────────────────────────────────────────────────────────
    Movement.step(self, dt, 80,
        CHASE_BOUND.x, CHASE_BOUND.y, CHASE_BOUND.x2, CHASE_BOUND.y2)

    -- ── Cat: sprint/pause cycle, flees to the farthest waypoint ──────────
    self.catRunT = self.catRunT + dt
    self.catPaused = (self.catRunT % 1.8) > 1.25   -- brief paw-lick windows
    if not self.catPaused then
        local pd = math.sqrt((self.cx-self.px)^2 + (self.cy-self.py)^2)
        if not self.catTarget or pd < 55 then
            self.catTarget = farthestWaypoint(self.px, self.py)
        end
        local tx, ty = self.catTarget[1], self.catTarget[2]
        local vx, vy = tx - self.cx, ty - self.cy
        local d = math.sqrt(vx*vx + vy*vy)
        if d > 4 then
            self.cx = self.cx + (vx/d) * 88 * dt
            self.cy = self.cy + (vy/d) * 88 * dt
        else
            self.catTarget = nil
        end
    end

    -- ── Catch / timeout ───────────────────────────────────────────────────
    local dist = math.sqrt((self.cx+8 - (self.px+8))^2 + (self.cy+8 - (self.py+10))^2)
    if dist < 15 then
        self.caught = true
        self.phase  = "chase_end"; self.pageT = 0
        self.audio.sfxPlay("win")
        self.audio.play("ending")
        return
    end
    self.chaseT = self.chaseT - dt
    if self.chaseT <= 0 then
        self.chaseT = 0
        self.caught = false
        self.phase  = "chase_end"; self.pageT = 0
        self.audio.sfxPlay("cat")
        self.audio.play("ending")
    end
end

function Ending:keypressed(key)
    if self.trans:isActive() then return end
    if self.phase == "chase" then
        self.keys[key] = true
        return
    end
    if key == "space" or key == "return" then
        if self.phase == "cake" then
            self.phase = "message"; self.pageT = 0
        elseif self.phase == "message" then
            if Collectibles.allCollected() then
                self.phase = "bonus"; self.pageT = 0
            else
                self.phase = "credits"; self.pageT = 0
            end
        elseif self.phase == "bonus" then
            self.phase = "credits"; self.pageT = 0
        elseif self.phase == "credits" then
            -- Surprise: post-credits scene instead of an instant restart
            self.phase = "chase_intro"; self.pageT = 0
            self.audio.sfxPlay("cat")
        elseif self.phase == "chase_intro" then
            self:_startChase()
        elseif self.phase == "chase_end" then
            self.phase = "blink"; self.pageT = 0
        elseif self.phase == "blink" then
            self.trans:fadeOut(function() self.sm:switch("intro") end, 1.0)
        end
        self.audio.sfxPlay("interact")
    end
end

function Ending:keyreleased(key)
    if self.keys then self.keys[key] = false end
end

-- ── Drawing ──────────────────────────────────────────────────────────────────
local function drawStarryBg(stars, t, tint)
    tint = tint or {0.05, 0.02, 0.12}
    love.graphics.setColor(tint[1], tint[2], tint[3])
    love.graphics.rectangle("fill", 0, 0, CW, CH)
    for _, st in ipairs(stars) do
        local b = 0.4 + 0.6*math.sin(t*1.4 + st.phase)
        love.graphics.setColor(1, 0.95, 0.85, b * 0.9)
        love.graphics.rectangle("fill", st.x, st.y, st.r > 1 and 2 or 1, st.r > 1 and 2 or 1)
    end
end

function Ending:draw()
    if self.phase == "cake" then
        drawStarryBg(self.stars, self.t, {0.06, 0.03, 0.14})
        -- Animated cake entrance
        local targetY = 40
        local cakeY   = math.max(targetY, CH - (CH - targetY) * math.min(1, self.t * 2))
        -- Gold burst
        love.graphics.setColor(1, 0.88, 0.25, 0.18 + 0.12*math.sin(self.t*3))
        love.graphics.rectangle("fill", CW/2-60, targetY-10, 120, 100)
        Sprites.drawCake(CW/2 - Sprites.cakeW/2, cakeY)
        -- The boyfriend, presenting the cake (rides up with it)
        Sprites.drawMarkoulinos(CW/2 + 24, cakeY + 4)

        -- Candle flicker above cake
        for i = -1, 1 do
            local fx = CW/2 + i*8
            local fy = cakeY - 6 + math.sin(self.t*8 + i)*2
            love.graphics.setColor(1, 0.85, 0.20, 0.9)
            love.graphics.rectangle("fill", fx-1, fy, 3, 5)
        end

        -- Title
        local titleA = math.min(1, self.t * 1.5)
        love.graphics.setColor(1, 0.85, 0.35, titleA)
        if self.font then love.graphics.setFont(self.font) end
        love.graphics.printf("THE CAKE IS FOUND!", 0, targetY + Sprites.cakeH + 10, CW, "center")

        love.graphics.setColor(1, 0.65, 0.78, titleA * (0.7 + 0.3*math.sin(self.t*2)))
        love.graphics.printf("Happy Birthday! *", 0, targetY + Sprites.cakeH + 24, CW, "center")

        if self.t > 1.5 then
            local blink = math.floor(self.t * 2) % 2 == 0
            if blink then
                love.graphics.setColor(0.75, 0.75, 0.75)
                love.graphics.printf("Press SPACE to continue", 0, CH - 18, CW, "center")
            end
        end

    elseif self.phase == "message" then
        drawStarryBg(self.stars, self.t, {0.08, 0.04, 0.18})

        love.graphics.setColor(0.10, 0.06, 0.18, 0.88)
        love.graphics.rectangle("fill", 14, 14, CW-28, CH-28)
        love.graphics.setColor(1, 0.78, 0.30)
        love.graphics.rectangle("line", 14, 14, CW-28, CH-28)

        love.graphics.setColor(1, 0.85, 0.35)
        if self.font then love.graphics.setFont(self.font) end
        love.graphics.printf("* A message *", 0, 22, CW, "center")

        local msg = [[
You are one of the most determined, graceful, and dramatically inclined people I know.

You danced on a broken toe, outwitted a suspicious father, survived a flour explosion, and recovered a birthday cake.

In other words: a completely normal Tuesday for you.

Happy Birthday. I love you.


        ]]
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(msg, 22, 40, CW-44, "center")

        local blink = math.floor(self.t * 2) % 2 == 0
        if blink then
            love.graphics.setColor(0.75, 0.75, 0.75)
            love.graphics.printf("Press SPACE to continue", 0, CH-18, CW, "center")
        end

    elseif self.phase == "bonus" then
        drawStarryBg(self.stars, self.t, {0.05, 0.10, 0.05})

        love.graphics.setColor(0.85, 0.60, 0.28)
        love.graphics.printf("* COOKIE MASTER! *", 0, 25, CW, "center")
        love.graphics.setColor(1, 0.90, 0.60)
        love.graphics.printf("You found ALL 4 cookies!", 0, 42, CW, "center")
        love.graphics.printf("That one on the kitchen counter...", 0, 58, CW, "center")
        love.graphics.printf("...how did it survive the chaos?", 0, 72, CW, "center")
        love.graphics.printf("Nobody knows. Nobody ever will.", 0, 86, CW, "center")

        -- Draw all 4 cookies in a row
        for i = 0, 3 do
            Sprites.drawCookie(90 + i * 35, 105)
        end

        local blink = math.floor(self.t * 2) % 2 == 0
        if blink then
            love.graphics.setColor(0.75, 0.75, 0.75)
            love.graphics.printf("Press SPACE for credits", 0, CH-18, CW, "center")
        end

    elseif self.phase == "credits" then
        drawStarryBg(self.stars, self.t, {0.04, 0.02, 0.10})

        love.graphics.setColor(1, 0.85, 0.35)
        if self.font then love.graphics.setFont(self.font) end
        love.graphics.printf("~ Credits ~", 0, 18, CW, "center")

        local pets = Collectibles.pets or 0
        local petLine
        if pets == 0 then
            petLine = "Cat petted: 0 times. She noticed."
        elseif pets == 1 then
            petLine = "Cat petted: once. Barely tolerated."
        else
            petLine = "Cat petted: "..pets.." times. She tolerated "
                      ..math.ceil(pets/3).." of them."
        end
        local lines = {
            "Birthday Cake Hunt",
            "A Birthday Gift Game",
            "",
            "Made with <3 and LOVE2D",
            "",
            "Starring: You",
            "Antagonist: TO PSIPSINI",
            "Comic Relief: Romanos",
            "Obstacle: Diogenis",
            "Cake Delivery: Markoulinos",
            "Cookies found: "..Collectibles.count().."/4",
            petLine,
            "* Go get the real cake! *",
        }
        love.graphics.setColor(0.90, 0.88, 0.85)
        for i, line in ipairs(lines) do
            love.graphics.printf(line, 0, 34 + i*10, CW, "center")
        end

        local blink = math.floor(self.t * 2) % 2 == 0
        if blink then
            love.graphics.setColor(0.60, 0.60, 0.60)
            love.graphics.printf("Press SPACE to play again", 0, CH-12, CW, "center")
        end

    elseif self.phase == "chase_intro" then
        drawStarryBg(self.stars, self.t, {0.03, 0.02, 0.08})
        love.graphics.setColor(0.85, 0.60, 0.28)
        if self.font then love.graphics.setFont(self.font) end
        love.graphics.printf("~ POST-CREDITS SCENE ~", 0, 30, CW, "center")
        love.graphics.setColor(0.90, 0.88, 0.85)
        love.graphics.printf("*the kitchen. again.*", 0, 55, CW, "center")
        love.graphics.printf("TO PSIPSINI has stolen a FIFTH cookie.", 0, 75, CW, "center")
        love.graphics.printf("This cannot stand.", 0, 89, CW, "center")
        love.graphics.setColor(1, 0.90, 0.60)
        love.graphics.printf("You have "..CHASE_TIME.." seconds. CATCH HER.", 0, 110, CW, "center")
        Sprites.drawCat(CW/2 - 8, 128)
        if math.floor(self.t * 2) % 2 == 0 then
            love.graphics.setColor(0.75, 0.75, 0.75)
            love.graphics.printf("Press SPACE to begin the hunt", 0, CH-18, CW, "center")
        end

    elseif self.phase == "chase" or self.phase == "chase_end" then
        -- Kitchen backdrop
        love.graphics.setColor(1, 1, 1)
        for tx = 0, CW, 48 do
            love.graphics.draw(WALL_IMG, WALL_TOP_Q, tx, 0)
            love.graphics.draw(WALL_IMG, WALL_BOT_Q, tx, 32)
        end
        for ty = 66, CH, 36 do
            for tx = 0, CW, 45 do
                love.graphics.draw(FLOOR_IMG, FLOOR_Q, tx, ty)
            end
        end

        -- Cat (sprinting between waypoints), cookie in tow
        Sprites.drawCat(self.cx, self.cy, not self.catPaused and self.phase == "chase")
        if self.phase == "chase" then
            Sprites.drawCookie(self.cx + 12, self.cy + 4)
            if self.catPaused then
                Dialogue.popup("*licks paw*", self.cx + 8, self.cy - 32, self.font)
            end
        end

        -- Player
        Sprites.drawPlayer(self.px, self.py, self.pdir, self.pmoving and self.phase == "chase")

        if self.phase == "chase" then
            -- Timer HUD
            love.graphics.setColor(0, 0, 0, 0.45)
            love.graphics.printf("CATCH THE CAT!", 1, 3, CW, "center")
            local urgent = self.chaseT < 5 and math.floor(self.t*4) % 2 == 0
            love.graphics.setColor(urgent and 1 or 1, urgent and 0.35 or 0.90, 0.35)
            love.graphics.printf(string.format("CATCH THE CAT!  %.1f", self.chaseT), 0, 2, CW, "center")
        else
            -- chase_end panel
            love.graphics.setColor(0.10, 0.06, 0.14, 0.85)
            love.graphics.rectangle("fill", 30, 42, CW-60, 84)
            love.graphics.setColor(1, 0.78, 0.30)
            love.graphics.rectangle("line", 30, 42, CW-60, 84)
            if self.font then love.graphics.setFont(self.font) end
            if self.caught then
                love.graphics.setColor(1, 0.90, 0.60)
                love.graphics.printf("YOU CAUGHT TO PSIPSINI!", 0, 52, CW, "center")
                love.graphics.setColor(0.90, 0.88, 0.85)
                love.graphics.printf("The cookie, however,\nis already gone.", 0, 72, CW, "center")
                love.graphics.printf("*distant swallowing noises*", 0, 100, CW, "center")
            else
                love.graphics.setColor(1, 0.60, 0.50)
                love.graphics.printf("TIME'S UP.", 0, 52, CW, "center")
                love.graphics.setColor(0.90, 0.88, 0.85)
                love.graphics.printf("TO PSIPSINI remains undefeated.", 0, 72, CW, "center")
                love.graphics.printf("She has always been undefeated.", 0, 88, CW, "center")
            end
            if math.floor(self.t * 2) % 2 == 0 then
                love.graphics.setColor(0.75, 0.75, 0.75)
                love.graphics.printf("Press SPACE", 0, CH-14, CW, "center")
            end
        end

    elseif self.phase == "blink" then
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", 0, 0, CW, CH)
        Sprites.drawCat(CW/2 - 8, CH/2 - 10)
        if self.pageT > 1.0 then
            love.graphics.setColor(1, 0.80, 0.88)
            if self.font then love.graphics.setFont(self.font) end
            love.graphics.printf("*slow blink*", 0, CH/2 + 18, CW, "center")
        end
        if self.pageT > 2.5 then
            love.graphics.setColor(1, 0.85, 0.35)
            love.graphics.printf("THE END", 0, 30, CW, "center")
            love.graphics.setColor(0.70, 0.70, 0.70)
            love.graphics.printf("(for real this time)", 0, 44, CW, "center")
            if math.floor(self.t * 2) % 2 == 0 then
                love.graphics.setColor(0.60, 0.60, 0.60)
                love.graphics.printf("Press SPACE to play again", 0, CH-12, CW, "center")
            end
        end
    end

    self.trans:draw(CW, CH)
    love.graphics.setColor(1,1,1)
end

return Ending
