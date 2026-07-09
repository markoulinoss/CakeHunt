-- Stage 4: The Grand Finale — broken-toe pep talk + harder rhythm battle
local Dialogue    = require "systems.dialogue"
local Transition  = require "systems.transition"
local Rhythm      = require "systems.rhythm"
local Collectibles = require "systems.collectibles"
local Sprites     = require "systems.sprites"
local Movement    = require "systems.movement"

local S4 = {}
S4.__index = S4

local CW, CH = 320, 180

function S4.new(sm, audio, font)
    local s   = setmetatable({}, S4)
    s.sm      = sm
    s.audio   = audio
    s.font    = font
    s.dlg     = Dialogue.new(function(n) audio.sfxPlay(n) end)
    s.trans   = Transition.new()
    -- Harder rhythm: more notes, faster fall, tighter spawn rhythm
    s.rhythm  = Rhythm.new({total=24, travelTime=0.95, spawnInterval=0.40,
                            sfxPlay=function(n) audio.sfxPlay(n) end})
    s.phase   = "pepTalk"  -- pepTalk|walkOn|battle|reveal|exit_ready
    s.px      = 20
    s.py      = 100
    s.pspeed  = 65
    s.keys    = {}
    s.flashT  = 0
    s.spotlightT = 0
    -- Cookie (hidden behind curtain, stage left)
    s.cookieX, s.cookieY = 18, 50
    s.cookiePicked= false
    s.nearCookie  = false
    return s
end

local PEP_LINES = {
    {speaker="You",    text="Ante na teleiwnoume kai me thn parastasi"},
    {speaker="You",    text="Ksekiname kai me tou Foniadaki..."},
    {speaker="You",    text="Kai exw kai spasmeno daxtylo"},
    {speaker="Nikhforos",text="(from offstage) Ela! Ksekiname paidia, pame!"},
    {speaker="You",    text="Ante na doume."},
}

local REVEAL_LINES = {
    {speaker="Audience", text="*thunderous applause*"},
    {speaker="Markoulinos",      text="...Geia. Sigxaritiriaa."},
    {speaker="You",      text="Kales oi kalogries?"},
    {speaker="Markoulinos",      text="Ennoeitai, pote tha sas dwsoun tin stoli eipame?"},
    {speaker="You",      text="Ahahaha, na ksereis... den foraw tipota apo katw"},
    {speaker="Markoulinos",      text="*Tou petaxthkan eksw ta matia*"},
}

function S4:enter()
    self.phase        = "pepTalk"
    self.px, self.py  = 20, 100
    self.cookiePicked = false
    self.keys         = {}
    self.flashT       = 0
    self.spotlightT   = 0
    self.audio.play("stage4")
    self.trans:fadeIn(0.6)
    self.dlg:start(PEP_LINES, function()
        self.phase = "walkOn"
    end)
end

function S4:exit() end

function S4:update(dt)
    self.trans:update(dt)
    self.flashT    = self.flashT    + dt
    self.spotlightT = self.spotlightT + dt

    if self.phase == "pepTalk" or self.phase == "reveal" then
        self.dlg:update(dt)
        return
    end

    if self.phase == "walkOn" then
        self.dlg:update(dt)
        -- Auto-walk player toward stage mark
        self.pdir, self.pmoving = "right", false
        if self.px < 145 then
            self.px = self.px + 55 * dt
            self.pmoving = true
        elseif not self.dlg:isActive() then
            self.phase = "battle"
            self.audio.play("final_stage")
            self.rhythm:start(function()
                self.audio.play("stage4")
                self.audio.sfxPlay("win")
                self.phase = "reveal"
                self.dlg:start(REVEAL_LINES, function()
                    self.phase = "exit_ready"
                end)
            end)
        end
        return
    end

    if self.phase == "battle" then
        self.rhythm:update(dt)
        return
    end

    if self.phase == "exit_ready" then
        self:_movePlayer(dt)
        -- Cookie pickup
        local pcx = self.px + 8; local pcy = self.py + 10
        self.nearCookie = not self.cookiePicked and
            math.abs(pcx - self.cookieX - 6) < 22 and math.abs(pcy - self.cookieY - 6) < 22
        if self.px >= CW - 12 and not self.trans:isActive() then
            self.trans:fadeOut(function() self.sm:switch("ending") end, 0.8)
        end
    end
end

function S4:_movePlayer(dt)
    Movement.step(self, dt, self.pspeed, 8, 35, CW-8, CH-55)
end

function S4:keypressed(key)
    self.keys[key] = true
    if self.trans:isActive() then return end

    if self.phase == "pepTalk" or self.phase == "reveal" then
        if key == "space" or key == "return" then
            self.dlg:advance()
            self.audio.sfxPlay("interact")
        end
        return
    end

    if self.phase == "battle" then
        self.rhythm:keypressed(key)
        return
    end

    if self.phase == "exit_ready" and (key == "space" or key == "e") then
        local pcx = self.px + 8; local pcy = self.py + 10
        if not self.cookiePicked and
           math.abs(pcx - self.cookieX - 6) < 22 and math.abs(pcy - self.cookieY - 6) < 22 then
            self.cookiePicked = true
            Collectibles.collect("stage4")
            self.audio.sfxPlay("pickup")
        end
    end
end

function S4:keyreleased(key) self.keys[key] = false end

-- ── Drawing ──────────────────────────────────────────────────────────────────
local function drawBackstage(phase, t)
    if phase == "pepTalk" then
        -- Dark backstage with a vertical gradient
        local steps = 5
        for i = 0, steps-1 do
            local tt = i / (steps-1)
            love.graphics.setColor(0.13-0.04*tt, 0.11-0.04*tt, 0.09-0.03*tt)
            love.graphics.rectangle("fill", 0, (CH/steps)*i, CW, CH/steps + 1)
        end
        -- Brick wall texture
        for row = 0, 8 do
            for col = 0, 20 do
                local shade = (row+col) % 2 == 0 and 0.18 or 0.15
                love.graphics.setColor(shade, shade*0.85, shade*0.75, 0.85)
                love.graphics.rectangle("fill", col*16 + (row%2)*8, row*20, 14, 18)
            end
        end
        -- Single warm work-light glow
        love.graphics.setColor(1, 0.85, 0.55, 0.10 + 0.03*math.sin(t*2))
        love.graphics.ellipse("fill", 60, 40, 50, 40)
        -- Hanging costumes with soft shadow
        for cx = 50, 250, 40 do
            love.graphics.setColor(0, 0, 0, 0.25)
            love.graphics.rectangle("fill", cx+2, 12, 12, 28)
            love.graphics.setColor(0.55, 0.20, 0.60, 0.8)
            love.graphics.rectangle("fill", cx, 10, 12, 28)
            love.graphics.setColor(0.75, 0.40, 0.80, 0.5)
            love.graphics.rectangle("fill", cx, 10, 3, 28)
            love.graphics.setColor(0.30, 0.30, 0.30)
            love.graphics.line(cx+6, 8, cx+6, 12)
        end
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.printf("Stage 4 - Backstage", 1, 3, CW, "center")
        love.graphics.setColor(0.55, 0.25, 0.58)
        love.graphics.printf("Stage 4 - Backstage", 0, 2, CW, "center")
    else
        -- Stage with spotlight
        love.graphics.setColor(0.05, 0.03, 0.10)
        love.graphics.rectangle("fill", 0, 0, CW, CH)
        -- Stage floor with subtle plank gradient
        love.graphics.setColor(0.45, 0.32, 0.18)
        love.graphics.rectangle("fill", 0, 110, CW, 70)
        love.graphics.setColor(0.38, 0.27, 0.15, 0.5)
        for fx = 0, CW, 20 do
            love.graphics.line(fx, 110, fx, CH)
        end
        -- Spotlight glow (layered for softness)
        local spotA = 0.20 + 0.08*math.sin(t*1.5)
        love.graphics.setColor(1, 0.95, 0.75, spotA*0.5)
        love.graphics.rectangle("fill", 60, 20, 200, 110)
        love.graphics.setColor(1, 0.92, 0.65, spotA)
        love.graphics.rectangle("fill", 80, 30, 160, 100)
        -- Curtains with fold highlights
        love.graphics.setColor(0.60, 0.10, 0.15)
        love.graphics.rectangle("fill", 0, 0, 35, CH)
        love.graphics.rectangle("fill", CW-35, 0, 35, CH)
        love.graphics.setColor(0.80, 0.25, 0.30, 0.4)
        for fy = 0, 7 do
            love.graphics.line(6+fy*4, 0, 6+fy*4, CH)
            love.graphics.line(CW-12+fy*4, 0, CW-12+fy*4, CH)
        end
        -- Audience silhouettes (rough bumps)
        love.graphics.setColor(0.08, 0.06, 0.04)
        for ax = 10, CW-35, 14 do
            local h = 12 + (ax % 7)
            love.graphics.rectangle("fill", ax, CH-h, 10, h)
        end
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.printf("Stage 4 - The Grand Finale", 1, 3, CW, "center")
        love.graphics.setColor(0.75, 0.58, 0.28)
        love.graphics.printf("Stage 4 - The Grand Finale", 0, 2, CW, "center")
    end
end

function S4:draw()
    local onStage = self.phase ~= "pepTalk"
    drawBackstage(self.phase, self.spotlightT)

    -- Cookie behind curtain
    if not self.cookiePicked then
        Sprites.drawCookie(self.cookieX, self.cookieY)
        if self.nearCookie then
            love.graphics.setColor(0.80, 1, 0.60)
            love.graphics.printf("[E] Cookie!", 0, self.cookieY-12, CW, "center")
        end
    end

    -- Player
    Sprites.drawPlayer(self.px, self.py, self.pdir,
        self.pmoving and (self.phase == "walkOn" or self.phase == "exit_ready"))

    -- Battle overlay
    if self.phase == "battle" then
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle("fill", 0, 0, CW, CH)
        -- Two silhouettes on "stage"
        Sprites.drawPlayer(100, 35, "right")
        Sprites.drawInstructor(175, 35)
        love.graphics.setColor(1, 0.90, 0.50, 0.3)
        love.graphics.rectangle("fill", 60, 25, 200, 55)
        self.rhythm:draw(160, 100, self.font)
    end

    -- Reveal: cake and boyfriend appear
    if self.phase == "reveal" or self.phase == "exit_ready" then
        Sprites.drawCake(140, 55)
        Sprites.drawMarkoulinos(195, 68)
    end

    -- HUD
    love.graphics.setColor(0.85, 0.70, 0.30)
    love.graphics.printf("Cookies: "..Collectibles.count().."/4", CW-70, 2, 68, "right")

    -- Dialogue
    if self.phase == "pepTalk" or self.phase == "reveal" then
        self.dlg:draw(self.font)
    end

    -- Exit hint
    if self.phase == "exit_ready" then
        love.graphics.setColor(0.85, 1, 0.65)
        love.graphics.printf("Walk right for the finale -->", 0, CH-12, CW, "center")
    end

    self.trans:draw(CW, CH)
    love.graphics.setColor(1,1,1)
end

return S4
