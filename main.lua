-- Birthday Cake Hunt — main entry point
-- Run: love .  (from the cake-hunt/ folder)

-- Must run BEFORE the state modules are required: they load images at
-- require time, and images snapshot the default filter when created.
love.graphics.setDefaultFilter("nearest", "nearest")

local StateMachine = require "systems.statemachine"
local Audio        = require "assets.audio"
local luis          = require "systems.luis_instance"
local Settings      = require "systems.settings_ui"

local Intro   = require "states.intro"
local Stage1  = require "states.stage1_studio"
local Stage2  = require "states.stage2_path"
local Stage3  = require "states.stage3_kitchen"
local Stage4  = require "states.stage4_finale"
local Ending  = require "states.ending"

-- Canvas dimensions (logical resolution)
local CW, CH    = 320, 180
local SCALE     = 3           -- 320×180 → 960×540
local canvas

local sm
local font
local paused = false

local function buildPauseMenu()
    luis.newLayer("pause")

    -- Grid is 48x27 cells (960x540 / 20); 12-wide elements centre at col 19
    local title = luis.newLabel("PAUSED", 12, 2, 7, 19, "center")
    luis.createElement("pause", "Label", title)

    local resumeBtn = luis.newButton("Resume", 12, 3,
        function() paused = false; luis.disableLayer("pause") end,
        function() end, 10, 19)
    luis.createElement("pause", "Button", resumeBtn)

    local settingsBtn = luis.newButton("Settings", 12, 3,
        function() Settings.open("pause") end,
        function() end, 13, 19)
    luis.createElement("pause", "Button", settingsBtn)

    local quitBtn = luis.newButton("Quit", 12, 3,
        function() Audio.stop(); love.event.quit() end,
        function() end, 16, 19)
    luis.createElement("pause", "Button", quitBtn)

    luis.disableLayer("pause")
end

function love.load()
    -- Canvas for low-res rendering
    canvas = love.graphics.newCanvas(CW, CH)
    canvas:setFilter("nearest", "nearest")

    -- Font (small, clean)
    -- Using default LÖVE font scaled to 8px equivalent on canvas
    font = love.graphics.newFont(8)
    love.graphics.setFont(font)

    -- Audio
    Audio.load()

    -- LUIS: real-resolution UI overlay (pause menu, settings, title
    -- screen, dialogue box), separate from the low-res game canvas so
    -- its text/buttons stay crisp.
    luis.updateScale()
    buildPauseMenu()
    Settings.build(Audio)

    -- State machine
    sm = StateMachine.new()
    sm:add("intro",   Intro.new(sm, Audio, font))
    sm:add("stage1",  Stage1.new(sm, Audio, font))
    sm:add("stage2",  Stage2.new(sm, Audio, font))
    sm:add("stage3",  Stage3.new(sm, Audio, font))
    sm:add("stage4",  Stage4.new(sm, Audio, font))
    sm:add("ending",  Ending.new(sm, Audio, font))

    sm:switch("intro")
end

function love.update(dt)
    -- Cap delta time to avoid spiral of death
    dt = math.min(dt, 0.05)

    -- LUIS always updates (title-screen buttons, dialogue typewriter,
    -- pause/settings widgets); only the game-state machine freezes
    -- while paused.
    luis.update(dt)
    luis.flux.update(dt)
    Audio.update(dt)

    if paused then return end
    sm:update(dt)
end

function love.draw()
    -- Draw everything to the low-res canvas
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setFont(font)

    sm:draw()

    -- Back to screen, scale up
    love.graphics.setCanvas()
    love.graphics.draw(canvas, 0, 0, 0, SCALE, SCALE)

    if paused then
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1)
    end

    -- All LUIS layers (title screen, dialogue box, pause, settings)
    -- draw here, at native resolution, on top of the scaled canvas.
    luis.draw()
end

function love.resize(w, h)
    luis.updateScale()
end

function love.keypressed(key, scancode, isrepeat)
    if isrepeat then return end
    if key == "escape" then
        paused = not paused
        if paused then
            luis.enableLayer("pause")
        else
            luis.disableLayer("pause")
            luis.disableLayer("settings")   -- may be open on top of the pause menu
        end
        return
    end
    if paused then
        luis.keypressed(key)
        return
    end
    sm:keypressed(key)
end

function love.keyreleased(key)
    -- Always forward releases, even while paused: swallowing them would
    -- leave movement keys stuck "held" after unpausing.
    sm:keyreleased(key)
end

function love.textinput(t)
    if paused then
        luis.textinput(t)
        return
    end
    sm:textinput(t)
end

function love.mousepressed(x, y, button, istouch, presses)
    luis.mousepressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    luis.mousereleased(x, y, button, istouch, presses)
end
