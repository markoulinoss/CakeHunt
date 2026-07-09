-- Intro: title screen → opening cutscene → hand off to stage 1
local Dialogue     = require "systems.dialogue"
local Transition   = require "systems.transition"
local Collectibles = require "systems.collectibles"

local Intro = {}
Intro.__index = Intro

local CW, CH = 320, 180

-- Drifting clouds for the opening cutscene backdrop
local CLOUD_IMGS = {}
for i = 1, 7 do
    CLOUD_IMGS[i] = love.graphics.newImage("assets/cloud_background/Cloud"..i..".png")
end

-- Title-screen cake: birthday_cake.png is 100×100, art occupies x 23..78,
-- y 4..88; drawn at 0.7 scale, centred under the title
local CAKE_IMG   = love.graphics.newImage("assets/birthday_cake.png")
local CAKE_SCALE = 0.7

function Intro.new(sm, audio, font)
    local s    = setmetatable({}, Intro)
    s.sm       = sm
    s.audio    = audio
    s.font     = font
    s.dlg      = Dialogue.new(function(n) audio.sfxPlay(n) end)
    s.trans    = Transition.new()
    s.phase    = "title"   -- title → story → fade
    s.titleT   = 0
    s.stars    = {}
    for i = 1, 40 do
        s.stars[i] = {x=love.math.random(CW), y=love.math.random(CH),
                      r=love.math.random()*0.8+0.2, t=love.math.random()*6}
    end
    s.clouds = {}
    for i = 1, 9 do
        local img = CLOUD_IMGS[love.math.random(#CLOUD_IMGS)]
        s.clouds[i] = {
            img = img,
            x   = love.math.random(-img:getWidth(), CW),
            y   = love.math.random(6, CH - 50),
            spd = 3 + love.math.random() * 7,      -- slow drift, px/s
            a   = 0.75 + love.math.random() * 0.25, -- clearly visible, slight depth variation
            sc  = 1 + love.math.random(),           -- 1x..2x
        }
    end
    return s
end

local OPENING -- forward-declared, defined below

function Intro:_beginStory()
    self.phase = "story"
    self.dlg:start(OPENING, function()
        self.trans:fadeOut(function()
            self.sm:switch("stage1")
        end, 0.7)
    end)
end

function Intro:enter()
    self.phase  = "title"
    self.titleT = 0
    Collectibles.reset()   -- fresh cookie count on every new run
    self.audio.play("intro")
    self.trans:fadeIn(0.8)
end

function Intro:exit() end

OPENING = {
    {speaker="Narrator", text="Happy Birthday! ..."},
    {speaker="Narrator", text="Something is terribly, catastrophically, dramatically wrong."},
    {speaker="Narrator", text="The cake. Is. MISSING."},
    {speaker="Narrator", text="Somewhere between the kitchen and the party, the birthday cake has vanished."},
    {speaker="Narrator", text="You have grace, determination, and a slightly dramatic streak."},
    {speaker="Narrator", text="You have 4 stages to track it down. The adventure begins NOW."},
}

function Intro:update(dt)
    self.trans:update(dt)
    self.titleT = self.titleT + dt
    for _, st in ipairs(self.stars) do st.t = st.t + dt end
    -- Clouds drift right and wrap around
    for _, c in ipairs(self.clouds) do
        c.x = c.x + c.spd * dt
        if c.x > CW then
            c.x = -c.img:getWidth() * c.sc
            c.y = love.math.random(6, CH - 50)
        end
    end
    if self.phase == "story" then
        self.dlg:update(dt)
    end
end

function Intro:keypressed(key)
    if self.trans:isActive() then return end
    if self.phase == "title" then
        if key == "space" or key == "return" then
            self:_beginStory()
        end
    elseif self.phase == "story" then
        if key == "space" or key == "return" then
            self.dlg:advance()
            self.audio.sfxPlay("interact")
        end
    end
end

function Intro:draw()
    -- Night-sky background
    love.graphics.setColor(0.05, 0.03, 0.12)
    love.graphics.rectangle("fill", 0, 0, CW, CH)

    -- Stars
    for _, st in ipairs(self.stars) do
        local b = 0.5 + 0.5*math.sin(st.t * 1.8)
        love.graphics.setColor(1, 0.95, 0.85, b * st.r)
        love.graphics.rectangle("fill", st.x, st.y, 1, 1)
    end

    if self.phase == "title" then
        -- The birthday cake, with a warm pulsing glow behind it
        local glow = 0.14 + 0.06*math.sin(self.titleT * 2)
        love.graphics.setColor(1, 0.80, 0.30, glow)
        love.graphics.ellipse("fill", CW/2, 115, 46, 40)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(CAKE_IMG,
            CW/2 - 50.5*CAKE_SCALE,   -- art centre → screen centre
            82   -  4.0*CAKE_SCALE,   -- art top → y 82, under the subtitle
            0, CAKE_SCALE, CAKE_SCALE)

        -- Title
        local pulse = 0.90 + 0.10*math.sin(self.titleT * 2.5)
        love.graphics.setColor(1, 0.85, 0.35, pulse)
        if self.font then love.graphics.setFont(self.font) end
        love.graphics.printf("Birthday Cake Hunt!", 0, 50, CW, "center")

        love.graphics.setColor(1, 0.70, 0.80)
        love.graphics.printf("A Birthday Adventure", 0, 66, CW, "center")

        -- Blink prompt
        if math.floor(self.titleT * 2) % 2 == 0 then
            love.graphics.setColor(0.85, 0.85, 0.85)
            love.graphics.printf("Press SPACE to begin", 0, CH - 30, CW, "center")
        end
    end

    if self.phase == "story" then
        -- Moonlit clouds drifting across the night sky
        for _, c in ipairs(self.clouds) do
            love.graphics.setColor(1, 1, 1, c.a)
            love.graphics.draw(c.img, c.x, c.y, 0, c.sc, c.sc)
        end

        self.dlg:draw(self.font)
    end

    self.trans:draw(CW, CH)
    love.graphics.setColor(1,1,1)
end

return Intro
