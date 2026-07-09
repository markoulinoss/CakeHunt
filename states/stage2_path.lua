-- Stage 2: The Path - Diogenis encounter + Romanos rescue
-- Pokemon-style trainer battle encounter
local Dialogue     = require "systems.dialogue"
local Transition   = require "systems.transition"
local Collectibles = require "systems.collectibles"
local Sprites      = require "systems.sprites"
local Movement     = require "systems.movement"
local BV           = require "systems.battle_visuals"

local S2 = {}
S2.__index = S2

local CW, CH = 320, 180

local DOUBT_MAX   = 100
local DOUBT_START = 40

local QUESTIONS = {
    {
        question = "Pou pas? Exeis sxolh aurio!!!",
        choices  = {
            {label="EXPLAIN", delta=-15, response="E, stis eratws paw. Gia ta genethlia mou."},
            {label="CHARM",   delta=-20, response="Kale mpampa twra se esena erxomoun."},
            {label="STALL",   delta= 10, response="Em, na parw terea?"},
            {label="RUN",     delta= 20, response="*sprints in the opposite direction*"},
        },
        hint = "Tip: EXPLAIN or CHARM tend to work better with strict dads.",
    },
    {
        question = "Giati den mou sikwneis to tilefono gamw??",
        choices  = {
            {label="EXPLAIN", delta=-10, response="Eisai sovaros?? Den to akousa. To exw kleisto gia tis proves"},
            {label="CHARM",   delta=-25, response="Mou teleiwse h mpataria kai bghka na to fortisw"},
            {label="STALL",   delta=  5, response="Nai alla o Ektwras ti kanei? Einai spiti?"},
            {label="RUN",     delta= 15, response="*points behind him* LOOK, AN EAGLE! *runs*"},
        },
        hint = "CHARM is working well here!",
    },
    {
        question = "Idia h mana sou eisai...",
        choices  = {
            {label="ACCEPT", delta=-15, response="Nai, nai kserw, eimaste oles poutanes."},
            {label="CHARM",   delta=-15, response="Bre den gamiesai kai esy prwiniatika."},
            {label="STALL",   delta= 10, response="Esy tin dialekses..."},
            {label="IGNORE",     delta= 30, response="*nods*, nai signomi."},
        },
        hint = "Either EXPLAIN or CHARM should get you through this one.",
    },
}

-- ── Script (dialogue lines) ───────────────────────────────────────────────────
local WALK_LINES = {
    {speaker="You", text="Ante na paw spiti siga siga"},
    {speaker="You", text="...elpizw na min me stamatisei tipota aproopto"},
}

local ROMANOS_LINES = {
    {speaker="Romanos", text="Kyrie Diogeni! Perimenete, sas exei skasei to lastixo"},
    {speaker="Diogenis", text="TI?! To lastixo?! ...Romane, ama mou les psemata--"},
    {speaker="Romanos", text="Egw? Psemata? To kalytero gallaki na pei psemata?"},
    {speaker="Diogenis", text="...emeis oi dyo den exoume teleiwsei, tha ta poume spiti!"},
    {speaker="You",      text="Eisai paixtis Romane."},
    {speaker="Romanos",  text="Nai, nai twra pigene bres tin tourta. Kai krata mou kai dyo kommatia"},
}

local AFTERMATH_LINES = {
    {speaker="You", text="Top stigmh."},
}

local DRIVE_INTRO_LINES = {
    {speaker="Romanos", text="Psst! Ela mpes -- Tha se paw egw spiti. Ela grigora prin to katalabei o Diogenis"},
    {speaker="You",     text="Ma, molis tou eipes oti exei lastixo."},
    {speaker="Romanos", text="LEPTOMEREIES. Ela mpes. Alla prosexe, o dromos exei empodia -- press SPACE to avoid."},
    {speaker="You",     text="Katse ti. Ti tha kan--"},
}

local DRIVE_DONE_LINES = {
    {speaker="Romanos", text="Edw eimaste! Eides, edw exw odigisei sto Mexico. To aygo tou mpampa sou einai paixnidaki"},
    {speaker="You",     text="Euxaristw??..."},
}

-- Rotating one-liners for the exit scene
local ROM_TALK = {
    "Einai polu xalia to lastixo, den to blepete?",
    "Kairo exw na sas dw kyrie Diogeni!",
    "Mou xrwstas ena kommati. Duo basika.",
    "*confident thumbs up*",
}

local DAD_TALK = {
    "...To lastixo einai mia xara. ROMANE!!",
    "*idia i mana sou...*",
    "Na eisai spiti prin tis 12!",
}

local HONK_LINE = "MHN AGGIZEIS TO AMAKSI!!"

-- ── Tuning constants ──────────────────────────────────────────────────────────
local easeOut = BV.easeOut
local function lerp(a, b, t) return a + (b-a)*t end

-- Pokemon strip-wipe speed (per-second progress of the 0->1 wipe)
local STRIP_SPEED = 2.8

-- Highway drive minigame
local DRIVE_TIME   = 25      -- seconds of driving
local DRIVE_SPEED  = 200     -- road scroll speed (px/s); obstacles match it
local DRIVE_CAR_X  = 20      -- car left edge on screen
local DRIVE_JUMP_V = -190    -- hop launch velocity
local DRIVE_GRAV   = 560

-- ── Construction / state ──────────────────────────────────────────────────────
function S2.new(sm, audio, font)
    local s   = setmetatable({}, S2)
    s.sm      = sm
    s.audio   = audio
    s.font    = font
    s.dlg     = Dialogue.new(function(n) audio.sfxPlay(n) end)
    -- Stage-2 only: play blink on every dialogue line, but only once
    -- Diogenis has shown up (car arrived)
    local function blink()
        if s.carArrived then audio.sfxPlay("blink") end
    end
    local baseStart, baseAdvance = s.dlg.start, s.dlg.advance
    s.dlg.start = function(dlg, lines, onDone)
        baseStart(dlg, lines, onDone)
        blink()
    end
    s.dlg.advance = function(dlg)
        local prevIdx = dlg.lineIdx
        baseAdvance(dlg)
        if dlg.active and dlg.lineIdx ~= prevIdx then blink() end
    end
    s.trans   = Transition.new()
    -- phases: walk | cararrival | encounter_flash | encounter_strips |
    --         battle_intro | battle | response | romanos | aftermath |
    --         exit_ready | drive_intro | drive | drive_done
    s.phase   = "walk"
    s.px, s.py= 20, 95
    s.keys    = {}
    s.doubt   = DOUBT_START
    s.qIdx    = 1
    s.selIdx  = 1
    s.showHint= false
    -- Car (184px wide; carX is its centre, so start fully off-screen left --
    -- the art faces right, so it drives in left-to-right)
    s.carX     = -100
    s.carMoving= false
    s.carTarget= 155
    s.carArrived=false
    -- Diogenis steps out right of the car (path scene)
    s.dadX, s.dadY = 255, 100
    -- Encounter animation
    s.flashWhite  = 0
    s.exclamT     = 0
    s.stripT      = 0
    s.introT      = 0
    -- Romanos arrival animation
    s.romStripT   = 0       -- gold strip wipe 0->1
    s.romIntroT   = 0       -- Romanos slide-in 0->1
    s.romBattleX  = CW + 50 -- Romanos X on battle screen (slides left)
    s.doubtDisplay= DOUBT_START  -- animated doubt value for drain effect
    s.draining    = false
    -- Cookie
    s.cookieX, s.cookieY = 90, 112
    s.cookieVisible = false
    s.cookiePicked  = false
    -- Re-talk / honk (exit_ready phase)
    s.romTalkIdx = 0
    s.dadTalkIdx = 0
    s.talkT      = 99
    s.talkLine   = ""
    s.talkX      = 0
    s.nearWho    = nil   -- "romanos" | "diogenis" | "car"
    -- Highway drive minigame
    s.driveT      = 0
    s.driveScroll = 0
    s.carJumpY    = 0    -- vertical hop offset (negative = airborne)
    s.carVY       = 0
    s.obstacles   = {}
    s.spawnT      = 0
    s.driveHits   = 0
    s.shakeT      = 0
    return s
end

function S2:enter()
    self.phase        = "walk"
    self.px, self.py  = 20, 95
    self.doubt        = DOUBT_START
    self.qIdx         = 1
    self.selIdx       = 1
    self.showHint     = false
    self.carX         = -100
    self.carMoving    = false
    self.carArrived   = false
    self.flashWhite   = 0
    self.exclamT      = 0
    self.stripT       = 0
    self.introT       = 0
    self.romStripT    = 0
    self.romIntroT    = 0
    self.romBattleX   = CW + 50
    self.doubtDisplay = DOUBT_START
    self.draining     = false
    self.cookieVisible= false
    self.cookiePicked = false
    self.romTalkIdx   = 0
    self.dadTalkIdx   = 0
    self.talkT        = 99
    self.talkLine     = ""
    self.nearWho      = nil
    self.driveT       = 0
    self.driveScroll  = 0
    self.carJumpY     = 0
    self.carVY        = 0
    self.obstacles    = {}
    self.spawnT       = 0
    self.driveHits    = 0
    self.shakeT       = 0
    self.keys         = {}
    self.audio.play("stage2")
    self.trans:fadeIn(0.6)
    self.dlg:start(WALK_LINES, function()
        self.carMoving = true
        self.phase     = "cararrival"
    end)
end

function S2:exit() end

-- ── Update ────────────────────────────────────────────────────────────────────
function S2:update(dt)
    self.trans:update(dt)

    -- ── Walk ─────────────────────────────────────────────────────────────────
    if self.phase == "walk" then
        self.dlg:update(dt)
        self.pdir, self.pmoving = "right", false
        if not self.dlg:isActive() and self.px < 80 then
            self.px = math.min(self.px + 40*dt, 80)
            self.pmoving = true
        end
        return
    end

    -- ── Car arrives ──────────────────────────────────────────────────────────
    if self.phase == "cararrival" then
        self.carX = self.carX + 160 * dt
        if self.carX >= self.carTarget then
            self.carX      = self.carTarget
            self.carArrived= true
            self.exclamT   = 0
            self.phase     = "encounter_flash"
            self.audio.sfxPlay("reveal")   -- sharp sting
        end
        return
    end

    -- ── "!" moment + white flash ─────────────────────────────────────────────
    if self.phase == "encounter_flash" then
        self.exclamT   = self.exclamT + dt
        self.flashWhite= math.max(0, 1 - self.exclamT * 2.5)
        if self.exclamT > 0.5 then
            -- start strip wipe
            self.phase  = "encounter_strips"
            self.stripT = 0
            self.audio.play("battle")   -- battle BGM kicks in
        end
        return
    end

    -- ── Pokemon strip-wipe ────────────────────────────────────────────────────
    if self.phase == "encounter_strips" then
        self.stripT = self.stripT + dt * STRIP_SPEED
        if self.stripT >= 1.0 then
            self.stripT = 1.0
            self.phase  = "battle_intro"
            self.introT = 0
            self.audio.sfxPlay("zubat")   -- Diogenis appears
        end
        return
    end

    -- ── Trainers slide in ─────────────────────────────────────────────────────
    -- Slide completes at introT=1; the extra time holds the
    -- "DIOGENIS wants to battle!" tag on screen (~1.5s) before the menu opens
    if self.phase == "battle_intro" then
        self.introT = self.introT + dt * 1.2
        if self.introT >= 2.4 then
            self.phase  = "battle"
            self.selIdx = 1
        end
        return
    end

    -- ── Battle (menu driven) ──────────────────────────────────────────────────
    if self.phase == "battle" then return end

    -- ── Response dialogue ─────────────────────────────────────────────────────
    if self.phase == "response" then
        self.dlg:update(dt)
        return
    end

    -- ── Romanos gold strip wipe ───────────────────────────────────────────────
    if self.phase == "romanos_strips" then
        self.romStripT = self.romStripT + dt * STRIP_SPEED
        if self.romStripT >= 1.0 then
            self.romStripT  = 1.0
            self.phase      = "romanos_intro"
            self.romIntroT  = 0
            self.romBattleX = CW + 50
            self.draining   = true
            self.audio.sfxPlay("pokeball")   -- Romanos appears
        end
        return
    end

    -- ── Romanos slides onto the battle screen ────────────────────────────────
    if self.phase == "romanos_intro" then
        self.romIntroT  = self.romIntroT + dt * 1.1
        self.romBattleX = lerp(CW + 50, 100, easeOut(math.min(1, self.romIntroT)))
        -- drain doubt meter dramatically
        if self.draining then
            self.doubtDisplay = math.max(0, self.doubtDisplay - dt * 120)
            if self.doubtDisplay <= 0 then
                self.doubtDisplay = 0
                self.draining     = false
                self.doubt        = 0
            end
        end
        -- Slide completes at romIntroT=1; the extra time holds the
        -- "ROMANOS appeared!" banner on screen before the dialogue starts
        if self.romIntroT >= 2.6 then
            self.phase     = "romanos"
            -- start dialogue on the battle screen
            self.dlg:start(ROMANOS_LINES, function()
                self.phase = "aftermath"
                self.cookieVisible = true
                self.audio.play("battle_end")   -- battle over, victory theme
                self.dlg:start(AFTERMATH_LINES, function()
                    self.phase = "exit_ready"
                end)
            end)
        end
        return
    end

    -- ── Romanos dialogue (on battle screen) ──────────────────────────────────
    if self.phase == "romanos" then
        self.dlg:update(dt)
        return
    end

    -- ── Aftermath ────────────────────────────────────────────────────────────
    if self.phase == "aftermath" then
        self.dlg:update(dt)
        return
    end

    -- ── Drive intro dialogue (hop in with Romanos) ───────────────────────────
    if self.phase == "drive_intro" then
        self.dlg:update(dt)
        return
    end

    -- ── Highway drive minigame ───────────────────────────────────────────────
    if self.phase == "drive" or self.phase == "drive_done" then
        self.driveScroll = self.driveScroll + DRIVE_SPEED * dt
        self.shakeT      = math.max(0, self.shakeT - dt)
        -- Car hop physics
        if self.carJumpY < 0 or self.carVY ~= 0 then
            self.carVY    = self.carVY + DRIVE_GRAV * dt
            self.carJumpY = self.carJumpY + self.carVY * dt
            if self.carJumpY >= 0 then self.carJumpY, self.carVY = 0, 0 end
        end
        if self.phase == "drive_done" then
            self.dlg:update(dt)
            return
        end
        self.driveT = self.driveT + dt
        -- Spawn obstacles until the ride is nearly over
        if self.driveT < DRIVE_TIME - 2 then
            self.spawnT = self.spawnT - dt
            if self.spawnT <= 0 then
                self.spawnT = 0.9 + math.random() * 0.8
                self.obstacles[#self.obstacles+1] =
                    {x = CW + 24, kind = math.random(3), hit = false}
            end
        end
        -- Move obstacles; collide against the car's front bumper only, so
        -- an obstacle sliding "under" the long car body reads as passed
        local frontL, frontR = DRIVE_CAR_X + 150, DRIVE_CAR_X + 184
        for i = #self.obstacles, 1, -1 do
            local o = self.obstacles[i]
            o.x = o.x - DRIVE_SPEED * dt
            if not o.hit and o.x < frontR and o.x + 14 > frontL and self.carJumpY > -10 then
                o.hit          = true
                self.driveHits = self.driveHits + 1
                self.shakeT    = 0.35
                self.audio.sfxPlay("miss")
            end
            if o.x < -20 then table.remove(self.obstacles, i) end
        end
        -- Ride over once the timer runs out and the road is clear
        if self.driveT >= DRIVE_TIME and #self.obstacles == 0 then
            self.phase = "drive_done"
            self.audio.sfxPlay("win")
            self.dlg:start(DRIVE_DONE_LINES, function()
                self.trans:fadeOut(function() self.sm:switch("stage3") end, 0.6)
            end)
        end
        return
    end

    -- ── Exit ─────────────────────────────────────────────────────────────────
    if self.phase == "exit_ready" then
        self.talkT = self.talkT + dt
        self:_movePlayer(dt)
        -- Who's in interaction range? (NPCs beat the car)
        local pcx, pcy = self.px + 8, self.py + 10
        self.nearWho = nil
        if math.abs(pcx - (228+8)) < 22 and math.abs(pcy - (102+10)) < 22 then
            self.nearWho = "romanos"
        elseif math.abs(pcx - (self.dadX+8)) < 22 and math.abs(pcy - (self.dadY+10)) < 22 then
            self.nearWho = "diogenis"
        elseif math.abs(pcx - self.carTarget) < 70 and pcy >= 96 then
            self.nearWho = "car"
        end
        if self.px >= CW - 16 and not self.trans:isActive() then
            self.px    = CW - 16
            self.phase = "drive_intro"
            self.dlg:start(DRIVE_INTRO_LINES, function()
                self.phase       = "drive"
                self.audio.play("car_chase", 2.5)   -- long crossfade out of the victory theme
                self.driveT      = 0
                self.driveScroll = 0
                self.carJumpY    = 0
                self.carVY       = 0
                self.obstacles   = {}
                self.spawnT      = 1.2
                self.driveHits   = 0
            end)
        end
        if self.cookieVisible and not self.cookiePicked and
           math.abs(pcx - self.cookieX) < 20 and math.abs(pcy - self.cookieY) < 20 then
            self.cookiePicked = true
            Collectibles.collect("stage2")
            self.audio.sfxPlay("pickup")
        end
    end
end

function S2:_movePlayer(dt)
    Movement.step(self, dt, 60, 8, 78, CW-10, CH-55)
end

function S2:_doChoice(choice)
    self.doubt = math.max(0, math.min(DOUBT_MAX, self.doubt + choice.delta))
    self.audio.sfxPlay(choice.delta <= 0 and "hit" or "miss")
    local responseLines = {
        {speaker="You",      text=choice.response},
        {speaker="Diogenis", text=
            choice.delta <= -15 and "Hmm. As poume oti einai... entaksei." or
            choice.delta <=   0 and "...Kala." or
            choice.delta <=  15 and "Den einai apantish auth!" or
                                    "TI KANEIS! Ela pisw!"},
    }
    self.phase = "response"
    self.dlg:start(responseLines, function()
        self.qIdx = self.qIdx + 1
        -- Romanos arrives after Q2 (partway through, per spec)
        if self.qIdx >= 3 then
            -- Trigger the Pokemon-style Romanos arrival transition
            self.phase     = "romanos_strips"
            self.romStripT = 0
        else
            self.phase    = "battle"
            self.selIdx   = 1
            self.showHint = false
        end
    end)
end

-- ── Input ─────────────────────────────────────────────────────────────────────
function S2:keypressed(key)
    self.keys[key] = true
    if self.trans:isActive() then return end

    -- Block input during transition animations
    if self.phase == "encounter_flash"  or self.phase == "encounter_strips" or
       self.phase == "battle_intro"     or
       self.phase == "romanos_strips"   or self.phase == "romanos_intro" then
        return
    end

    -- Dialogue-driven phases
    if self.phase == "walk" or self.phase == "response" or
       self.phase == "romanos" or self.phase == "aftermath" or
       self.phase == "drive_intro" or self.phase == "drive_done" then
        if key == "space" or key == "return" then
            self.dlg:advance()
            self.audio.sfxPlay("interact")
        end
        return
    end

    -- Highway drive: SPACE hops the car over obstacles
    if self.phase == "drive" then
        if (key == "space" or key == "return" or key == "up" or key == "w")
           and self.carJumpY == 0 and self.carVY == 0 then
            self.carVY    = DRIVE_JUMP_V
            self.carJumpY = -0.01   -- leaves the ground this frame
            self.audio.sfxPlay("interact")
        end
        return
    end

    -- Exit phase: chat with the boys, honk the car
    if self.phase == "exit_ready" and (key == "space" or key == "e") then
        if self.nearWho == "romanos" then
            self.romTalkIdx = self.romTalkIdx % #ROM_TALK + 1
            self.talkLine   = ROM_TALK[self.romTalkIdx]
            self.talkX      = 228
            self.talkT      = 0
            -- Occasionally he pipes up out loud (music ducks so he's heard)
            if love.math.random() < 0.5 then
                self.romSndIdx = (self.romSndIdx or 0) % 2 + 1
                self.audio.duckFor("romanos"..self.romSndIdx)
                self.audio.sfxPlay("romanos"..self.romSndIdx)
            else
                self.audio.sfxPlay("interact")
            end
        elseif self.nearWho == "diogenis" then
            self.dadTalkIdx = self.dadTalkIdx % #DAD_TALK + 1
            self.talkLine   = DAD_TALK[self.dadTalkIdx]
            self.talkX      = self.dadX
            self.talkT      = 0
            self.audio.sfxPlay("interact")
        elseif self.nearWho == "car" then
            self.talkLine   = HONK_LINE
            self.talkX      = self.dadX
            self.talkT      = 0
            self.audio.sfxPlay("honk")
        end
        return
    end

    -- Battle menu: arrow keys navigate the 2x2 grid, space/enter confirms
    if self.phase == "battle" then
        local q = QUESTIONS[self.qIdx]
        if not q then return end
        self.selIdx = BV.navMenu(self.selIdx, key, #q.choices)
        if key == "space" or key == "return" then
            self:_doChoice(q.choices[self.selIdx])
        end
        if key == "h" then self.showHint = true end
        return
    end
end

function S2:keyreleased(key) self.keys[key] = false end

-- ── Drawing helpers ───────────────────────────────────────────────────────────
-- Miami-synth layered background. The layers are 240px tall; the canvas is
-- 180, so everything is drawn at native scale shifted up 60px (crops sky,
-- keeps the road at the bottom). back/buildings/palms tile horizontally;
-- highway is a designed 896px strip so we show the lamp-post slice of it.
local BG_BACK  = love.graphics.newImage("assets/sprites/environment/Miami-synth-files/Layers/back.png")
local BG_SUN   = love.graphics.newImage("assets/sprites/environment/Miami-synth-files/Layers/sun.png")
local BG_BLD   = love.graphics.newImage("assets/sprites/environment/Miami-synth-files/Layers/buildings.png")
local BG_PALMS = love.graphics.newImage("assets/sprites/environment/Miami-synth-files/Layers/palms.png")
local BG_HWY   = love.graphics.newImage("assets/sprites/environment/Miami-synth-files/Layers/highway.png")

local function drawPath()
    local dy = -60
    love.graphics.setColor(1,1,1)
    for x = 0, CW, 224 do love.graphics.draw(BG_BACK, x, dy) end
    love.graphics.draw(BG_SUN, -40, dy)
    for x = 0, CW, 256 do love.graphics.draw(BG_BLD, x, dy) end
    for x = 0, CW, 224 do love.graphics.draw(BG_PALMS, x, dy) end
    love.graphics.draw(BG_HWY, -60, dy)
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.printf("Stage 2 - The Path", 1, 3, CW, "center")
    love.graphics.setColor(1, 0.85, 0.55)
    love.graphics.printf("Stage 2 - The Path", 0, 2, CW, "center")
end

-- Scrolling parallax version of the path for the highway drive. Each layer
-- moves at its own fraction of the road speed; the highway layer moves at
-- full speed so the road matches the obstacles.
local function drawTiled(img, w, off, dy)
    local xo = -(off % w)
    for x = xo, CW, w do love.graphics.draw(img, x, dy) end
end

local function drawDrivePath(scroll)
    local dy = -60
    love.graphics.setColor(1, 1, 1)
    drawTiled(BG_BACK,  224, scroll * 0.08, dy)
    love.graphics.draw(BG_SUN, -40, dy)
    drawTiled(BG_BLD,   256, scroll * 0.25, dy)
    drawTiled(BG_PALMS, 224, scroll * 0.50, dy)
    drawTiled(BG_HWY,   896, scroll,        dy)
end

-- Road junk for the drive: cone / lost tyre / crate, sitting on the road.
-- Hit obstacles fade out instead of disappearing.
local function drawObstacle(o)
    local baseY = 158
    local a = o.hit and 0.35 or 1
    if o.kind == 1 then      -- traffic cone
        love.graphics.setColor(1, 0.55, 0.15, a)
        love.graphics.polygon("fill", o.x, baseY, o.x+14, baseY, o.x+7, baseY-14)
        love.graphics.setColor(1, 1, 1, a * 0.9)
        love.graphics.rectangle("fill", o.x+4, baseY-7, 6, 2)
    elseif o.kind == 2 then  -- lost tyre (a VERY flat one, presumably)
        love.graphics.setColor(0.15, 0.15, 0.18, a)
        love.graphics.circle("fill", o.x+7, baseY-6, 7)
        love.graphics.setColor(0.45, 0.45, 0.50, a)
        love.graphics.circle("fill", o.x+7, baseY-6, 3)
    else                     -- crate
        love.graphics.setColor(0.62, 0.42, 0.20, a)
        love.graphics.rectangle("fill", o.x, baseY-13, 14, 13)
        love.graphics.setColor(0.40, 0.26, 0.12, a)
        love.graphics.rectangle("line", o.x, baseY-13, 14, 13)
    end
end

-- Doubt meter colour shifts green -> yellow -> red as doubt rises
local function drawDoubtPanel(doubt, font)
    local pct = doubt / DOUBT_MAX
    BV.drawEnemyPanel("DIOGENIS  DOUBT", pct,
        {math.min(1, pct*2), math.min(1, (1-pct)*2), 0.10}, font)
end

function S2:draw()
    local phase = self.phase

    -- ── Overworld (walk / car arrival) ───────────────────────────────────────
    if phase == "walk" or phase == "cararrival" or phase == "encounter_flash" then
        drawPath()
        if self.carArrived or self.carMoving or phase == "encounter_flash" then
            Sprites.drawCar(self.carX - Sprites.carW/2, 97, self.carMoving)
        end
        if self.carArrived then
            Sprites.drawDiogenis(self.dadX, self.dadY, "left")
        end
        Sprites.drawPlayer(self.px, self.py, self.pdir, self.pmoving)

        -- "!" exclamation above player
        if phase == "encounter_flash" and self.exclamT < 0.5 then
            love.graphics.setColor(0.10, 0.10, 0.10)
            love.graphics.rectangle("fill", self.px+5, self.py-32, 10, 14)
            love.graphics.setColor(1, 0.85, 0.10)
            love.graphics.rectangle("fill", self.px+6, self.py-31, 8, 12)
            love.graphics.setColor(0.10, 0.10, 0.10)
            if self.font then love.graphics.setFont(self.font) end
            love.graphics.print("!", self.px+8, self.py-30)
        end

        -- White flash overlay
        if self.flashWhite > 0 then
            love.graphics.setColor(1, 1, 1, self.flashWhite)
            love.graphics.rectangle("fill", 0, 0, CW, CH)
        end

        if phase == "walk" or (phase == "encounter_flash" and self.exclamT < 0.3) then
            self.dlg:draw(self.font)
        end
    end

    -- ── Strip wipe ────────────────────────────────────────────────────────────
    if phase == "encounter_strips" then
        -- Draw the path scene underneath briefly
        drawPath()
        Sprites.drawCar(self.carX - Sprites.carW/2, 97)
        Sprites.drawDiogenis(self.dadX, self.dadY, "left")
        Sprites.drawPlayer(self.px, self.py, self.pdir)
        -- Overlay strips
        BV.drawStrips(self.stripT)
    end

    -- ── Battle intro: trainers slide in from off-screen ───────────────────────
    if phase == "battle_intro" then
        BV.drawField()
        local t = easeOut(math.min(1, self.introT))
        -- Diogenis: slides in from right (large, 3x scale)
        local dadTargetX = 195
        local dadStartX  = CW + 50
        local dadX = lerp(dadStartX, dadTargetX, t)
        -- Draw Diogenis at 3x scale manually
        love.graphics.push()
        love.graphics.translate(dadX, 32)
        love.graphics.scale(3, 3)
        Sprites.drawDiogenis(0, 0)
        love.graphics.pop()
        -- Player: slides in from left (2x scale, positioned lower/nearer)
        local plTargetX = 30
        local plStartX  = -60
        local plX = lerp(plStartX, plTargetX, t)
        love.graphics.push()
        love.graphics.translate(plX, 78)
        love.graphics.scale(2, 2)
        Sprites.drawPlayer(0, 0, "up")
        love.graphics.pop()
        -- Name tag fades in (top-left, same spot as the doubt panel)
        if self.introT > 0.6 then
            local a = math.min(1, (self.introT - 0.6) * 4)
            love.graphics.setColor(0.92, 0.90, 0.85, a)
            love.graphics.rectangle("fill", 8, 8, 142, 36)
            love.graphics.setColor(0.20, 0.20, 0.20, a)
            love.graphics.rectangle("line", 8, 8, 142, 36)
            if self.font then love.graphics.setFont(self.font) end
            love.graphics.setColor(0.10, 0.10, 0.10, a)
            love.graphics.print("DIOGENIS wants to battle!", 13, 18)
        end
    end

    -- ── Battle screen ─────────────────────────────────────────────────────────
    if phase == "battle" or phase == "response" then
        BV.drawField()
        -- Panels behind the sprites so they don't cover Diogenis
        drawDoubtPanel(self.doubt, self.font)
        BV.drawPlayerPanel(self.font)
        -- Diogenis (right, large, 3x)
        love.graphics.push()
        love.graphics.translate(195, 32)
        love.graphics.scale(3, 3)
        Sprites.drawDiogenis(0, 0)
        love.graphics.pop()
        -- Player (left, 2x)
        love.graphics.push()
        love.graphics.translate(30, 78)
        love.graphics.scale(2, 2)
        Sprites.drawPlayer(0, 0, "up")
        love.graphics.pop()

        if phase == "battle" then
            local q = QUESTIONS[self.qIdx]
            if q then
                BV.drawMenu(q.question, q.choices, self.selIdx, self.font, q.hint, self.showHint)
            end
        end
        if phase == "response" then
            self.dlg:draw(self.font)
        end
    end

    -- ── Romanos gold strip wipe (over the battle screen) ─────────────────────
    if phase == "romanos_strips" then
        -- Battle scene underneath
        BV.drawField()
        drawDoubtPanel(self.doubtDisplay, self.font)
        BV.drawPlayerPanel(self.font)
        love.graphics.push()
        love.graphics.translate(195, 32)
        love.graphics.scale(3, 3)
        Sprites.drawDiogenis(0, 0)
        love.graphics.pop()
        love.graphics.push()
        love.graphics.translate(30, 78)
        love.graphics.scale(2, 2)
        Sprites.drawPlayer(0, 0, "up")
        love.graphics.pop()
        -- Gold/white strips, reversed direction from the encounter (heroic)
        BV.drawStrips(self.romStripT, {c1={1, 0.88, 0.20}, c2={1, 1, 1}, reverse=true})
    end

    -- ── Romanos slides onto the battle screen ────────────────────────────────
    if phase == "romanos_intro" then
        BV.drawField()
        drawDoubtPanel(self.doubtDisplay, self.font)
        BV.drawPlayerPanel(self.font)
        -- Diogenis (backing away slightly as introT grows)
        local dadShift = easeOut(math.min(1, self.romIntroT)) * 18
        love.graphics.push()
        love.graphics.translate(195 + dadShift, 32)
        love.graphics.scale(3, 3)
        Sprites.drawDiogenis(0, 0)
        love.graphics.pop()
        -- Player
        love.graphics.push()
        love.graphics.translate(30, 78)
        love.graphics.scale(2, 2)
        Sprites.drawPlayer(0, 0, "up")
        love.graphics.pop()
        -- Romanos slides in from right (3x scale, heroic entrance)
        love.graphics.push()
        love.graphics.translate(self.romBattleX, 44)
        love.graphics.scale(3, 3)
        Sprites.drawRomanos(0, 0)
        love.graphics.pop()
        -- "ROMANOS appeared!" banner
        if self.romIntroT > 0.5 then
            local a = math.min(1, (self.romIntroT - 0.5) * 3)
            love.graphics.setColor(0.95, 0.88, 0.20, a)
            love.graphics.rectangle("fill", 20, 68, CW-40, 18)
            love.graphics.setColor(0.15, 0.10, 0.05, a)
            love.graphics.rectangle("line", 20, 68, CW-40, 18)
            if self.font then love.graphics.setFont(self.font) end
            love.graphics.setColor(0.10, 0.08, 0.02, a)
            love.graphics.printf("ROMANOS appeared!", 0, 72, CW, "center")
        end
    end

    -- ── Romanos dialogue (on battle screen) ──────────────────────────────────
    if phase == "romanos" then
        BV.drawField()
        drawDoubtPanel(0, self.font)   -- doubt is zero
        BV.drawPlayerPanel(self.font)
        -- Diogenis retreating (shifted right)
        love.graphics.push()
        love.graphics.translate(213, 32)
        love.graphics.scale(3, 3)
        Sprites.drawDiogenis(0, 0)
        love.graphics.pop()
        -- Romanos (centre, 3x)
        love.graphics.push()
        love.graphics.translate(100, 44)
        love.graphics.scale(3, 3)
        Sprites.drawRomanos(0, 0)
        love.graphics.pop()
        -- Player (left, 2x)
        love.graphics.push()
        love.graphics.translate(30, 78)
        love.graphics.scale(2, 2)
        Sprites.drawPlayer(0, 0, "up")
        love.graphics.pop()
        self.dlg:draw(self.font)
    end

    -- ── Aftermath + exit (back to path) ──────────────────────────────────────
    if phase == "aftermath" or phase == "exit_ready" or phase == "drive_intro" then
        drawPath()
        if self.carArrived then
            Sprites.drawCar(self.carTarget - Sprites.carW/2, 97)
        end
        -- Romanos steering Diogenis away toward the "flat tyre"
        Sprites.drawDiogenis(self.dadX, self.dadY, "left")
        Sprites.drawRomanos(228, 102)
        if self.cookieVisible and not self.cookiePicked then
            Sprites.drawCookie(self.cookieX, self.cookieY)
            love.graphics.setColor(0.80, 1, 0.60)
            love.graphics.printf("Walk over to pick up!", 0, self.cookieY-10, CW, "center")
        end
        Sprites.drawPlayer(self.px, self.py, self.pdir, self.pmoving and phase == "exit_ready")
        if phase == "exit_ready" then
            love.graphics.setColor(0.85, 1, 0.65)
            love.graphics.printf("Walk right to hop in with Romanos -->", 0, CH-12, CW, "center")
            -- Interaction prompt / talk popup
            if self.talkT < 2 then
                Dialogue.popup(self.talkLine, self.talkX + 8, 62, self.font)
            elseif self.nearWho then
                love.graphics.setColor(1, 0.90, 0.35)
                local prompt = self.nearWho == "car" and "[E] Honk" or "[E] Talk"
                love.graphics.printf(prompt, 0, 86, CW, "center")
            end
        else
            self.dlg:draw(self.font)
        end
    end

    -- ── Highway drive minigame ────────────────────────────────────────────────
    if phase == "drive" or phase == "drive_done" then
        love.graphics.push()
        if self.shakeT > 0 then
            love.graphics.translate((math.random()-0.5)*4, (math.random()-0.5)*3)
        end
        drawDrivePath(self.driveScroll)
        for _, o in ipairs(self.obstacles) do drawObstacle(o) end
        Sprites.drawCar(DRIVE_CAR_X, 97 + self.carJumpY, true)
        love.graphics.pop()
        -- Progress bar to the house
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle("fill", 60, 6, 200, 8)
        love.graphics.setColor(0.35, 0.90, 0.55)
        love.graphics.rectangle("fill", 61, 7, 198 * math.min(1, self.driveT / DRIVE_TIME), 6)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.rectangle("line", 60, 6, 200, 8)
        if self.font then love.graphics.setFont(self.font) end
        love.graphics.setColor(1, 0.85, 0.55)
        love.graphics.print("To the house!", 62, 16)
        if self.driveHits > 0 then
            love.graphics.setColor(1, 0.55, 0.45)
            love.graphics.print("Bumps: "..self.driveHits, 62, 26)
        end
        if phase == "drive" and self.driveT < 4 then
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.printf("SPACE to jump!", 0, CH-14, CW, "center")
        end
        if phase == "drive_done" then
            self.dlg:draw(self.font)
        end
    end

    -- ── Cookie HUD ────────────────────────────────────────────────────────────
    local hideHUD = phase == "encounter_strips" or phase == "battle_intro"
                 or phase == "romanos_strips"   or phase == "romanos_intro"
    if not hideHUD then
        love.graphics.setColor(0.85, 0.70, 0.30)
        love.graphics.printf("Cookies: "..Collectibles.count().."/4", CW-70, 2, 68, "right")
    end

    self.trans:draw(CW, CH)
    love.graphics.setColor(1, 1, 1)
end

return S2
