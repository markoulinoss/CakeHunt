-- Stage 1: Dance Studio
-- Flow: intro dialogue → walk to instructor → rhythm battle → collect optional cookie → exit
local Dialogue    = require "systems.dialogue"
local Transition  = require "systems.transition"
local Rhythm      = require "systems.rhythm"
local Collectibles = require "systems.collectibles"
local Sprites     = require "assets.sprites"
local Movement    = require "systems.movement"

local S1 = {}
S1.__index = S1

local CW, CH = 320, 180
local FLOOR_Y = 66

-- Room bounds for player movement
local BOUND = {x=12, y=FLOOR_Y+2, x2=CW-12, y2=CH-60}

function S1.new(sm, audio, font)
    local s   = setmetatable({}, S1)
    s.sm      = sm
    s.audio   = audio
    s.font    = font
    s.dlg     = Dialogue.new(function(n) audio.sfxPlay(n) end)
    s.trans   = Transition.new()
    s.rhythm  = Rhythm.new({total=16, travelTime=1.3, spawnInterval=0.55,
                            sfxPlay=function(n) audio.sfxPlay(n) end})
    s.phase   = "intro"   -- intro|explore|battle|win|exit
    -- Player state
    s.px, s.py  = 30, 110
    s.pspeed    = 75
    s.keys      = {}
    -- NPC / object positions
    s.instrX, s.instrY = 130, 80
    s.instrDefeated    = false
    -- Cookie
    s.cookieX, s.cookieY = 280, 76   -- on the open floor so the player can reach it
    s.cookieVisible      = false
    s.cookiePicked       = false
    -- Exit door (right wall, mid-height)
    s.exitX, s.exitY = CW-14, 90
    s.exitOpen       = false
    -- Misc
    s.flashTimer = 0
    s.winTimer   = 0
    s.hintTimer  = 0
    -- Re-talk (after the battle Lida sticks around)
    s.talkIdx    = 0
    s.talkT      = 99
    return s
end

local INTRO_LINES = {
    {speaker="You",        text="Thelw na pethanw. Paw na fygw apo edw"},
    {speaker="Lida", text="IRIDAAAA? Giati feygeis apo twra?"},
    {speaker="Lida", text="A nai to ksexasa exeis spasmeno daxtylo alla etsi einai oi kallitenxes..."},
    {speaker="You",        text="Ama sou pw kai esena tipota twra!"},
    {speaker="Lida", text="Pame 5,6,7,8!"},
}

local LIDA_TALK = {
    "200 koiliakous. Twra.",
    "Akoma edw eisai? Ante!",
    "Prosexe to daxtylo, kallitexnida mou.",
    "*stretches aggressively*",
}

local WIN_LINES = {
    {speaker="Lida", text="Ntaksei, kati kaneis"},
    {speaker="Lida", text="Ante kala mporeis na fygeis..."},
    {speaker="You",        text="Na sai kala..."},
}

function S1:enter()
    self.phase         = "intro"
    self.px, self.py   = 30, 110
    self.instrDefeated = false
    self.cookieVisible = false
    self.cookiePicked  = false
    self.exitOpen      = false
    self.keys          = {}
    self.talkIdx       = 0
    self.talkT         = 99
    self.audio.play("stage1")
    self.trans:fadeIn(0.6)
    self.dlg:start(INTRO_LINES, function() self.phase = "explore" end)
end

function S1:exit() end

function S1:update(dt)
    self.trans:update(dt)
    self.flashTimer = self.flashTimer + dt
    self.hintTimer  = self.hintTimer + dt
    self.talkT      = self.talkT + dt

    if self.phase == "intro" or self.phase == "win" then
        self.dlg:update(dt)
        if self.phase == "win" then
            self.winTimer = self.winTimer + dt
            if self.winTimer > 0.5 and not self.dlg:isActive() then
                self.phase = "exit_ready"
                self.exitOpen = true
                self.cookieVisible = true
            end
        end
        return
    end

    if self.phase == "battle" then
        self.rhythm:update(dt)
        return
    end

    if self.phase == "explore" or self.phase == "exit_ready" then
        self:_movePlayer(dt)
        self:_checkInteractions()
    end
end

function S1:_movePlayer(dt)
    Movement.step(self, dt, self.pspeed,
        BOUND.x, BOUND.y, BOUND.x2 - Sprites.playerW, BOUND.y2 - Sprites.playerH)
end

function S1:_dist(ax, ay, bx, by)
    return math.sqrt((ax-bx)^2 + (ay-by)^2)
end

function S1:_checkInteractions()
    local pcx = self.px + Sprites.playerW/2
    local pcy = self.py + Sprites.playerH/2
    -- Near instructor? (battle before the win, chat after)
    self.nearInstr = self:_dist(pcx, pcy, self.instrX+8, self.instrY+10) < 30
    -- Near cookie?
    self.nearCookie = self.cookieVisible and not self.cookiePicked and
        self:_dist(pcx, pcy, self.cookieX+6, self.cookieY+6) < 24
    -- Near exit?
    self.nearExit = self.exitOpen and self:_dist(pcx, pcy, self.exitX, self.exitY) < 22
end

function S1:keypressed(key)
    self.keys[key] = true
    if self.trans:isActive() then return end

    if self.phase == "intro" or self.phase == "win" then
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

    if (key == "space" or key == "e") then
        if self.nearInstr and self.instrDefeated then
            -- Re-talk: rotating one-liners
            self.talkIdx = self.talkIdx % #LIDA_TALK + 1
            self.talkT   = 0
            self.audio.sfxPlay("interact")
        elseif self.nearInstr then
            self.phase = "battle"
            self.audio.play("dance_battle")
            self.rhythm:start(function()
                -- Won the battle
                self.audio.play("stage1")
                self.audio.sfxPlay("win")
                self.instrDefeated = true
                self.phase         = "win"
                self.winTimer      = 0
                self.dlg:start(WIN_LINES, function() end)
            end)
        elseif self.nearCookie then
            self.cookiePicked = true
            Collectibles.collect("stage1")
            self.audio.sfxPlay("pickup")
        elseif self.nearExit then
            self.trans:fadeOut(function() self.sm:switch("stage2") end, 0.6)
        end
    end
end

function S1:keyreleased(key) self.keys[key] = false end

-- ── Drawing helpers ──────────────────────────────────────────────────────────
-- Studio art: walls.png grey-stone texture (content rows 5..54; two stacked
-- slices with a 15-row offset cover the 66px wall band seamlessly, same
-- trick as the kitchen), Floor.png brick tile as wood parquet, and
-- "livingroom furniture.png" pieces for the home-studio props.
local FLOOR_IMG = love.graphics.newImage("assets/Floor.png")
local WALL_IMG  = love.graphics.newImage("assets/walls.png")
local FURN_IMG  = love.graphics.newImage("assets/livingroom furniture.png")

local function furnQ(x, y, w, h) return love.graphics.newQuad(x, y, w, h, FURN_IMG:getDimensions()) end
local FLOOR_Q    = love.graphics.newQuad(1, 6, 45, 35, FLOOR_IMG:getDimensions())    -- brick/parquet tile
local WALL_TOP_Q = love.graphics.newQuad(207,  5, 48, 32, WALL_IMG:getDimensions())  -- grey stone
local WALL_BOT_Q = love.graphics.newQuad(207, 21, 48, 34, WALL_IMG:getDimensions())
local FURN = {
    bookshelf = furnQ( 19,  23, 26, 56),
    tv        = furnQ(148,  46, 43, 31),
    sofa      = furnQ( 17,  94, 62, 33),
    sideboard = furnQ( 53,  53, 54, 26),
    window    = furnQ(258, 100, 27, 28),
    rugWhite  = furnQ(213, 147, 50, 14),
    rugGreen  = furnQ(277, 147, 50, 14),
    rugRed    = furnQ(214, 179, 50, 14),
    rugBlue   = furnQ(277, 179, 50, 14),
}

local function drawFloor()
    love.graphics.setColor(1, 1, 1)
    -- Wall band, then parquet floor
    for tx = 0, CW, 48 do
        love.graphics.draw(WALL_IMG, WALL_TOP_Q, tx, 0)
        love.graphics.draw(WALL_IMG, WALL_BOT_Q, tx, 32)
    end
    for ty = FLOOR_Y, CH, 35 do
        for tx = 0, CW, 45 do
            love.graphics.draw(FLOOR_IMG, FLOOR_Q, tx, ty)
        end
    end
    -- Windows on the wall
    love.graphics.draw(FURN_IMG, FURN.window,  78, 4)
    love.graphics.draw(FURN_IMG, FURN.window, 225, 8)
    -- Furniture along the back wall (bottoms aligned at y=66)
    love.graphics.draw(FURN_IMG, FURN.bookshelf,  12, 10)
    love.graphics.draw(FURN_IMG, FURN.tv,         60, 35)
    love.graphics.draw(FURN_IMG, FURN.sofa,      150, 33)
    love.graphics.draw(FURN_IMG, FURN.sideboard, 262, 40)
    -- Rugs as dance mats; the white one marks the instructor's spot
    love.graphics.draw(FURN_IMG, FURN.rugWhite, 105,  95)
    love.graphics.draw(FURN_IMG, FURN.rugRed,    40, 130)
    love.graphics.draw(FURN_IMG, FURN.rugBlue,  210, 125)
    love.graphics.draw(FURN_IMG, FURN.rugGreen, 140, 148)
    -- Studio name on the wall
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.printf("* KERAMEIKOS *", 1, 9, CW, "center")
    love.graphics.setColor(1, 0.92, 0.75)
    love.graphics.printf("* KERAMEIKOS *", 0, 8, CW, "center")
end

local function drawExit(open, x, y, flash)
    if open then
        local glow = 0.5 + 0.5*math.sin(flash*4)
        love.graphics.setColor(0.90, 1, 0.70, glow)
        love.graphics.rectangle("fill", x-6, y-12, 12, 24)
        love.graphics.setColor(0.20, 0.80, 0.20)
        love.graphics.rectangle("line", x-6, y-12, 12, 24)
        love.graphics.setColor(1,1,1)
        love.graphics.printf(">", x-10, y-4, 20, "center")
    else
        love.graphics.setColor(0.40, 0.30, 0.20)
        love.graphics.rectangle("fill", x-6, y-12, 12, 24)
        love.graphics.setColor(0.25, 0.20, 0.12)
        love.graphics.rectangle("line", x-6, y-12, 12, 24)
    end
end

function S1:draw()
    drawFloor()

    -- Instructor (sticks around after the battle for a chat)
    Sprites.drawInstructor(self.instrX, self.instrY)
    if self.talkT < 2 then
        Dialogue.popup(LIDA_TALK[self.talkIdx], self.instrX + 8, self.instrY - 60, self.font)
    elseif self.nearInstr then
        love.graphics.setColor(1, 0.90, 0.35)
        love.graphics.printf(self.instrDefeated and "[E] Talk" or "[E] Dance Battle!",
            0, self.instrY - 12, CW, "center")
    end

    -- Cookie (if visible)
    if self.cookieVisible and not self.cookiePicked then
        Sprites.drawCookie(self.cookieX, self.cookieY)
        if self.nearCookie then
            love.graphics.setColor(0.80, 1, 0.60)
            love.graphics.printf("[E] Cookie?!", 0, self.cookieY-10, CW, "center")
        end
    end

    -- Exit
    drawExit(self.exitOpen, self.exitX, self.exitY, self.flashTimer)
    if self.nearExit then
        love.graphics.setColor(0.90, 1, 0.70)
        love.graphics.printf("[E] Leave studio", 0, self.exitY - 22, CW, "center")
    end

    -- Player
    Sprites.drawPlayer(self.px, self.py, self.pdir,
        self.pmoving and (self.phase == "explore" or self.phase == "exit_ready"))

    -- HUD
    love.graphics.setColor(1, 0.85, 0.35)
    love.graphics.printf("Stage 1 - Dance Studio", 0, 2, CW, "center")
    love.graphics.setColor(0.85, 0.70, 0.30)
    love.graphics.printf("Cookies: "..Collectibles.count().."/4", CW-70, 2, 68, "right")

    -- Hint
    if self.phase == "explore" and self.hintTimer > 2 and not self.instrDefeated then
        love.graphics.setColor(0.65, 0.65, 0.65)
        love.graphics.printf("Walk to the instructor  |  WASD/Arrows to move", 0, CH-10, CW, "center")
    end

    -- Battle overlay
    if self.phase == "battle" then
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", 0, 0, CW, CH)
        Sprites.drawInstructor(60, 40)
        Sprites.drawPlayer(220, 40, "left")
        self.rhythm:draw(160, 90, self.font)
    end

    -- Dialogue
    if self.phase == "intro" or self.phase == "win" then
        self.dlg:draw(self.font)
    end

    self.trans:draw(CW, CH)
    love.graphics.setColor(1,1,1)
end

return S1
