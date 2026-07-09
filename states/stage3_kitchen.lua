-- Stage 3: Kitchen Disaster — cleanup minigame
local Dialogue     = require "systems.dialogue"
local Transition   = require "systems.transition"
local Collectibles = require "systems.collectibles"
local Sprites      = require "assets.sprites"
local Movement     = require "systems.movement"
local BV           = require "systems.battle_visuals"

local S3 = {}
S3.__index = S3

local CW, CH = 320, 180
local FLOOR_Y = 66
local BOUND   = {x=10, y=FLOOR_Y+2, x2=CW-10, y2=CH-55}

-- Catch-the-ingredients minigame
local CATCH_GOAL = 12

local easeOut = BV.easeOut
local function lerp(a, b, t) return a + (b-a)*t end

-- Mess items: {x,y,label,icon_color,cleaned}
local function defaultMess()
    return {
        {x= 60, y= 80, label="Flour Bag",    col={1,0.95,0.90}, cleaned=false, remessed=false},
        {x=130, y= 72, label="Toppled Bowl", col={0.85,0.65,0.45}, cleaned=false, remessed=false},
        {x=200, y=100, label="Spilled Milk", col={0.95,0.95,1.00}, cleaned=false, remessed=false},
        {x= 85, y=115, label="Knocked Chair",col={0.60,0.38,0.20}, cleaned=false, remessed=false},
        {x=240, y= 74, label="Frosting Smear",col={1,0.72,0.80}, cleaned=false, remessed=false},
    }
end

function S3.new(sm, audio, font)
    local s   = setmetatable({}, S3)
    s.sm      = sm
    s.audio   = audio
    s.font    = font
    s.dlg     = Dialogue.new(function(n) audio.sfxPlay(n) end)
    s.trans   = Transition.new()
    -- phases: intro | explore | catdash | bake_intro | catch | catch_done |
    --         note | after_note | exit_ready |
    --         catflash | catstrips | catbattle_intro | catbattle | catresponse | catend
    s.phase   = "intro"
    s.px, s.py = 30, 100
    s.pspeed  = 72
    s.keys    = {}
    s.mess    = defaultMess()
    s.catX    = -20
    s.catDir  = 1
    s.catDashing = false
    s.catDone    = false
    s.catIdleX   = 260
    s.catIdleT   = 0
    s.noteVisible= false
    s.noteRead   = false
    s.cookieX, s.cookieY = 285, 70   -- on the floor below the cupboard, within walk-over range
    s.cookiePicked= false
    s.flashT      = 0
    s.nearMessIdx = nil
    s.nearNote    = false
    s.nearCat     = false
    s.petCount    = 0
    s.petT        = 99   -- time since last pet (drives the reaction popup)
    -- Catch-the-ingredients minigame
    s.bakeDone = false
    s.bowlX    = CW/2
    s.items    = {}
    s.caught   = 0
    s.spawnT   = 0
    s.panT     = 0
    s.catchT   = 0
    s.panFlash = 0
    -- Cat rematch (Pokemon style, at the exit)
    s.catBattleDone = false
    s.catRound      = 1
    s.catSel        = 1
    s.catExclamT    = 0
    s.catFlashWhite = 0
    s.catStripT     = 0
    s.catIntroT     = 0
    s.catLeaveT     = 0
    s.endDlgStarted = false
    return s
end

local INTRO_LINES = {
    {speaker="Psipsini",  text="..."},
    {speaker="Psipsini",  text="*sits in the middle of the catastrophic flour explosion*"},
    {speaker="Psipsini",  text="*looks directly at you*"},
    {speaker="Psipsini",  text="*slowly blinks*"},
    {speaker="You",  text="Entwmetaksi gt me efere spiti tou markou?"},
    {speaker="You",  text="...Pou einai o paparas? Giati einai pali i kouzina poutana?"},
    {speaker="Psipsini",  text="*tail flick*"},
    {speaker="You",  text="Wx thee mou... Katse na mazepsw tipota, den mporw na ta blepw."},
}

local CAT_DASH_LINES = {
    {speaker="Psipsini",  text="*YEET*"},
    {speaker="You",  text="E-- mwrh-- Molis katharisa."},
    {speaker="Psipsini",  text="*meow*"},
}

local NOTE_LINES = {
    {speaker="Note", text="Efyga grigora giati exw argisei kai eprepe na piasw thesi."},
    {speaker="Note", text="Den prolaba na mazepsw oups."},
    {speaker="Note", text="PS anypomonw na se dw kalogria. Ta leme stin parastasi :)"},
}

local AFTER_NOTE_LINES = {
    {speaker="You", text="E bebaia. Telos pantwn"},
    {speaker="You", text="...exoume kai tin parastasi."},
}

local BAKE_INTRO_LINES = {
    {speaker="You", text="Ksereis ti, oriaka tha kanw egw tin tourta"},
    {speaker="Psipsini", text="*judgmental ears*"},
}

local CATCH_DONE_LINES = {
    {speaker="You", text="Nai, kalytera oxi gama to. Den ginetai na mageirepsei kaneis edw mesa"},
    {speaker="Psipsini", text="*slow blink of pure judgment*"},
    {speaker="You", text="A -- katse, exei ena simeiwma"},
}

-- Cat rematch: every option fails, every round. The meter never moves.
local CAT_ROUNDS = {
    {
        question = "TO PSIPSINI stares directly through you.",
        choices  = {
            {label="EXPLAIN",    response="You explain about the cake, the show, the broken toe. Everything."},
            {label="BRIBE",      response="You offer a treat. TO PSIPSINI sniffs it, then looks at you with disappointment."},
            {label="STARE BACK", response="You enter a staring contest. You lose in four seconds."},
            {label="BEG",        response="You get on your knees. TO PSIPSINI finds this acceptable. And insufficient."},
        },
    },
    {
        question = "TO PSIPSINI slowly blinks.",
        choices  = {
            {label="EXPLAIN",    response="You explain that slow blinking means love. TO PSIPSINI blinks again. Slower. Sarcastically."},
            {label="BRIBE",      response="You rattle the treat bag. TO PSIPSINI knows it is empty. TO PSIPSINI has always known."},
            {label="STARE BACK", response="You slow-blink back. TO PSIPSINI looks mildly embarrassed for you."},
            {label="BEG",        response="You say 'pleeeease' in the special voice. TO PSIPSINI'S tail flicks once."},
        },
    },
    {
        question = "TO PSIPSINI sits in the doorway. Deliberately.",
        choices  = {
            {label="EXPLAIN",    response="You explain you REALLY have to get to the show. TO PSIPSINI begins washing a paw."},
            {label="BRIBE",      response="You promise cake. TO PSIPSINI knows there is no cake. That is the whole problem."},
            {label="STARE BACK", response="You point firmly at the door. TP PSIPSINI looks at your finger."},
            {label="BEG",        response="You attempt puppy eyes. On a cat. Bold strategy."},
        },
    },
}

local CAT_END_LINES = {
    {speaker="", text="TO PSIPSINI was not defeated."},
    {speaker="", text="TO PSIPSINI simply left."},
    {speaker="You", text="...ti pio synithes!"},
}

function S3:enter()
    self.phase        = "intro"
    self.px, self.py  = 30, 100
    self.mess         = defaultMess()
    self.catX         = self.catIdleX
    self.catDashing   = false
    self.catDone      = false
    self.noteVisible  = false
    self.noteRead     = false
    self.cookiePicked = false
    self.keys         = {}
    self.flashT       = 0
    self.catIdleT     = 0
    self.petCount     = 0
    self.petT         = 99
    self.bakeDone     = false
    self.bowlX        = CW/2
    self.items        = {}
    self.caught       = 0
    self.spawnT       = 0
    self.panT         = 0
    self.catchT       = 0
    self.panFlash     = 0
    self.catBattleDone= false
    self.catRound     = 1
    self.catSel       = 1
    self.catExclamT   = 0
    self.catFlashWhite= 0
    self.catStripT    = 0
    self.catIntroT    = 0
    self.catLeaveT    = 0
    self.endDlgStarted= false
    self.audio.play("kitchen_music")
    self.trans:fadeIn(0.6)
    self.dlg:start(INTRO_LINES, function()
        self.phase = "explore"
    end)
end

function S3:exit() end

function S3:_allCleaned()
    for _, m in ipairs(self.mess) do
        if not m.cleaned then return false end
    end
    return true
end

function S3:_cleanedCount()
    local n = 0
    for _, m in ipairs(self.mess) do if m.cleaned then n = n + 1 end end
    return n
end

function S3:update(dt)
    self.trans:update(dt)
    self.flashT = self.flashT + dt
    self.catIdleT = self.catIdleT + dt
    self.petT = self.petT + dt

    -- The dash runs regardless of phase: skipping the dash dialogue faster
    -- than her ~1s sprint must not strand her mid-kitchen.
    if self.catDashing then
        self.catX = self.catX + self.catDir * 350 * dt
        if self.catDir > 0 and self.catX > CW + 20 then
            self.catDashing = false
            self.catDone    = true
            self.catX       = self.catIdleX -- back to idle (teleport)
            -- force a re-mess on first cleaned item
            for _, m in ipairs(self.mess) do
                if m.cleaned and not m.remessed then
                    m.cleaned  = false
                    m.remessed = true
                    break
                end
            end
        end
    end

    if self.phase == "intro" or self.phase == "catdash" or
       self.phase == "note"  or self.phase == "after_note" or
       self.phase == "bake_intro" or self.phase == "catch_done" then
        self.dlg:update(dt)
        return
    end

    if self.phase == "explore" then
        self:_movePlayer(dt)
        -- Cat idle wander
        if not self.catDone and not self.catDashing then
            self.catX = self.catIdleX + 10 * math.sin(self.catIdleT * 0.7)
        end
        self:_checkCatTrigger()
        -- Check for near mess items
        self:_checkNearMess()
        -- All cleaned -> replacement-cake gag (catch minigame), then the note
        if self:_allCleaned() and not self.bakeDone then
            self.phase = "bake_intro"
            self.audio.sfxPlay("reveal")
            self.dlg:start(BAKE_INTRO_LINES, function()
                self.phase  = "catch"
                self.bowlX  = CW/2
                self.items  = {}
                self.caught = 0
                self.spawnT = 0.5
                self.panT   = 3.0
                self.catchT = 0
            end)
        end
    end

    -- ── Catch the ingredients ────────────────────────────────────────────────
    if self.phase == "catch" then
        self.catchT   = self.catchT + dt
        self.panFlash = math.max(0, self.panFlash - dt)
        -- Bowl movement
        local dx = 0
        if self.keys["left"]  or self.keys["a"] then dx = -1 end
        if self.keys["right"] or self.keys["d"] then dx =  1 end
        self.bowlX = math.max(16, math.min(CW-16, self.bowlX + dx * 145 * dt))
        -- Cat paces along the top of the cupboards, plotting
        self.catX = 200 + 60 * math.sin(self.catIdleT * 0.9)
        -- Ingredient rain
        self.spawnT = self.spawnT - dt
        if self.spawnT <= 0 then
            self.spawnT = 0.55 + math.random() * 0.4
            self.items[#self.items+1] = {
                x = 20 + math.random() * (CW - 40), y = -8,
                vy = 60 + math.random() * 30,
                kind = math.random(2) == 1 and "egg" or "milk",
            }
        end
        -- The cat occasionally knocks a frying pan into the mix
        self.panT = self.panT - dt
        if self.panT <= 0 then
            self.panT = 3 + math.random() * 2
            self.items[#self.items+1] = {x = self.catX + 8, y = 30, vy = 90, kind = "pan"}
            self.audio.sfxPlay("cat")
        end
        -- Fall + catch (bowl rim sits at y=138)
        for i = #self.items, 1, -1 do
            local it = self.items[i]
            it.y = it.y + it.vy * dt
            if it.y >= 130 and it.y <= 146 and math.abs(it.x - self.bowlX) < 17 then
                if it.kind == "pan" then
                    self.caught   = math.max(0, self.caught - 2)
                    self.panFlash = 0.4
                    self.audio.sfxPlay("miss")
                else
                    self.caught = self.caught + 1
                    self.audio.sfxPlay("hit")
                end
                table.remove(self.items, i)
            elseif it.y > CH + 10 then
                table.remove(self.items, i)
            end
        end
        if self.caught >= CATCH_GOAL then
            self.bakeDone = true
            self.items    = {}
            self.catX     = self.catIdleX
            self.phase    = "catch_done"
            self.audio.sfxPlay("win")
            self.dlg:start(CATCH_DONE_LINES, function()
                self.noteVisible = true
                self.phase = "explore"
            end)
        end
        return
    end

    -- ── Cat rematch: encounter animation ─────────────────────────────────────
    if self.phase == "catflash" then
        self.catExclamT    = self.catExclamT + dt
        self.catFlashWhite = math.max(0, 1 - self.catExclamT * 2.5)
        if self.catExclamT > 0.5 then
            self.phase     = "catstrips"
            self.catStripT = 0
            self.audio.play("battle")
        end
        return
    end
    if self.phase == "catstrips" then
        self.catStripT = self.catStripT + dt * 2.8
        if self.catStripT >= 1.0 then
            self.phase     = "catbattle_intro"
            self.catIntroT = 0
            self.audio.sfxPlay("zubat")
        end
        return
    end
    -- Slide completes at catIntroT=1; the extra time holds the
    -- "THE CAT blocks the way!" banner, same duration as Diogenis's intro
    if self.phase == "catbattle_intro" then
        self.catIntroT = self.catIntroT + dt * 1.2
        if self.catIntroT >= 2.4 then
            self.phase  = "catbattle"
            self.catSel = 1
        end
        return
    end
    if self.phase == "catbattle" then return end
    if self.phase == "catresponse" then
        self.dlg:update(dt)
        return
    end
    if self.phase == "catend" then
        self.catLeaveT = math.min(1, self.catLeaveT + dt * 0.8)
        if self.catLeaveT >= 1 and not self.endDlgStarted then
            self.endDlgStarted = true
            self.dlg:start(CAT_END_LINES, function()
                self.catBattleDone = true
                self.audio.play("kitchen_music")
                self.phase = "exit_ready"
                -- Step back from the doorway so the exit doesn't re-trigger
                -- instantly; the player keeps control (pet the cat, cookie)
                -- and walks right again when ready.
                self.px   = CW - 70
                self.catX = self.catIdleX
            end)
        end
        self.dlg:update(dt)
        return
    end

    if self.phase == "exit_ready" then
        self:_movePlayer(dt)
        self:_checkNearMess()   -- keeps nearCat fresh so she stays pettable
        -- Cookie
        if not self.cookiePicked then
            local pcx = self.px + 8; local pcy = self.py + 10
            if math.abs(pcx - self.cookieX) < 20 and math.abs(pcy - self.cookieY) < 20 then
                self.cookiePicked = true
                Collectibles.collect("stage3")
                self.audio.sfxPlay("pickup")
            end
        end
        if self.px >= CW - 14 and not self.trans:isActive() then
            if not self.catBattleDone then
                -- THE CAT blocks the way. Pokemon rules apply.
                self.px            = CW - 14
                self.catX          = self.catIdleX
                self.phase         = "catflash"
                self.catExclamT    = 0
                self.catFlashWhite = 1
                self.catRound      = 1
                self.catLeaveT     = 0
                self.endDlgStarted = false
                self.audio.sfxPlay("reveal")
            else
                self.trans:fadeOut(function() self.sm:switch("stage4") end, 0.6)
            end
        end
    end
end

function S3:_movePlayer(dt)
    Movement.step(self, dt, self.pspeed, BOUND.x, BOUND.y, BOUND.x2, BOUND.y2-20)
end

function S3:_checkNearMess()
    local pcx = self.px+8; local pcy = self.py+10
    self.nearMessIdx = nil
    for i, m in ipairs(self.mess) do
        if not m.cleaned then
            if math.abs(pcx - (m.x+8)) < 25 and math.abs(pcy - (m.y+8)) < 25 then
                self.nearMessIdx = i
                break
            end
        end
    end
    -- Near note?
    self.nearNote = self.noteVisible and not self.noteRead and
        math.abs(pcx - 160) < 30 and math.abs(pcy - 90) < 30
    -- Near cat? (she sits at y=95, wanders around catX; after the rematch she
    -- "leaves"... and is immediately back at her spot, because cat)
    self.nearCat = not self.catDashing and
        math.abs(pcx - (self.catX + 8)) < 26 and math.abs(pcy - (95 + 8)) < 26
    -- The frosting smear's zone overlaps the cat's: when both are in range,
    -- target whichever is closer so the cat is actually pettable there.
    if self.nearCat and self.nearMessIdx then
        local m = self.mess[self.nearMessIdx]
        local dMess = (pcx-(m.x+8))^2  + (pcy-(m.y+8))^2
        local dCat  = (pcx-(self.catX+8))^2 + (pcy-(95+8))^2
        if dCat < dMess then self.nearMessIdx = nil else self.nearCat = false end
    end
end

function S3:_checkCatTrigger()
    -- After cleaning 2 items (and cat hasn't dashed yet), trigger cat dash
    if not self.catDone and not self.catDashing and self:_cleanedCount() >= 2 then
        self.catDashing = true
        self.catDir     = 1
        self.catX       = -20
        self.phase      = "catdash"
        self.audio.sfxPlay("cat")
        self.dlg:start(CAT_DASH_LINES, function()
            self.phase = "explore"
        end)
    end
end

-- Cat rematch: whatever you pick, the meter stays at zero
function S3:_catChoice(choice)
    self.audio.sfxPlay("miss")
    self.phase = "catresponse"
    self.dlg:start({
        {speaker="", text=choice.response},
        {speaker="", text="THE PSIPSINI'S INTEREST remains at zero."},
    }, function()
        self.catRound = self.catRound + 1
        if self.catRound > #CAT_ROUNDS then
            self.phase     = "catend"
            self.catLeaveT = 0
        else
            self.phase  = "catbattle"
            self.catSel = 1
        end
    end)
end

function S3:keypressed(key)
    self.keys[key] = true
    if self.trans:isActive() then return end

    if self.phase == "intro" or self.phase == "catdash" or
       self.phase == "note"  or self.phase == "after_note" or
       self.phase == "bake_intro" or self.phase == "catch_done" or
       self.phase == "catresponse" or self.phase == "catend" then
        if key == "space" or key == "return" then
            self.dlg:advance()
            self.audio.sfxPlay("interact")
        end
        return
    end

    -- Block input during cat-battle transition animations
    if self.phase == "catflash" or self.phase == "catstrips" or
       self.phase == "catbattle_intro" or self.phase == "catch" then
        return
    end

    -- Cat battle menu: 2x2 grid, same navigation as the stage 2 battle
    if self.phase == "catbattle" then
        local q = CAT_ROUNDS[self.catRound]
        if not q then return end
        self.catSel = BV.navMenu(self.catSel, key, #q.choices)
        if key == "space" or key == "return" then
            self:_catChoice(q.choices[self.catSel])
        end
        return
    end

    if (key == "space" or key == "e") and
       (self.phase == "explore" or self.phase == "exit_ready") then
        if self.phase == "explore" and self.nearMessIdx then
            self.mess[self.nearMessIdx].cleaned = true
            self.audio.sfxPlay("clean")
        elseif self.nearCat then
            self.petCount = self.petCount + 1
            self.petT     = 0
            Collectibles.pet()
            local meow = "meow"..(1 + (self.petCount - 1) % 3)
            self.audio.duckFor(meow)
            self.audio.sfxPlay(meow)
        elseif self.phase == "explore" and self.nearNote then
            self.noteRead = true
            self.phase    = "note"
            self.dlg:start(NOTE_LINES, function()
                self.phase = "after_note"
                self.dlg:start(AFTER_NOTE_LINES, function()
                    self.phase = "exit_ready"
                end)
            end)
        end
    end
end

function S3:keyreleased(key) self.keys[key] = false end

-- ── Drawing ──────────────────────────────────────────────────────────────────
-- Kitchen art: Floor.png (three 45×36 tiles, 9px pattern so they tile
-- seamlessly), walls.png (three 48×80 wall textures), and
-- "kitchen furniture.png" (loose furniture pieces, quads below).
local FLOOR_IMG = love.graphics.newImage("assets/Floor.png")
local WALL_IMG  = love.graphics.newImage("assets/walls.png")
local FURN_IMG  = love.graphics.newImage("assets/kitchen furniture.png")
-- Catch-minigame ingredients (16×16 each)
local EGG_IMG   = love.graphics.newImage("assets/egg_white.png")
local MILK_IMG  = love.graphics.newImage("assets/milk_bottled.png")
-- Cat corner props: Pet_Food_Bowls.png is a 4×5 sheet of 16×16 bowls,
-- Pet_Kibble_Bags.png a 12×5 sheet of 32×32 bags
local PET_BOWL_IMG = love.graphics.newImage("assets/Pet_Food_Bowls.png")
local PET_BAG_IMG  = love.graphics.newImage("assets/Pet_Kibble_Bags.png")
local BOWL_Q       = love.graphics.newQuad(32, 0, 16, 16, PET_BOWL_IMG:getDimensions())  -- red, some kibble
local BAG_CLOSED_Q = love.graphics.newQuad(0,  0, 32, 32, PET_BAG_IMG:getDimensions())   -- folded shut
local BAG_OPEN_Q   = love.graphics.newQuad(128, 0, 32, 32, PET_BAG_IMG:getDimensions())  -- kibble spilling out

local function furnQ(x, y, w, h) return love.graphics.newQuad(x, y, w, h, FURN_IMG:getDimensions()) end
local FLOOR_Q = love.graphics.newQuad(49, 5, 45, 36, FLOOR_IMG:getDimensions())  -- blue tile
-- Sandy brick wall: the texture's content occupies rows 5..54 of the 80-tall
-- file (the rest is transparent). Two stacked slices cover the 66px wall
-- band; the 15-row offset between them matches the brick course period, so
-- the seam is invisible, and the bottom slice ends on the texture's last row.
local WALL_TOP_Q = love.graphics.newQuad(112,  5, 48, 32, WALL_IMG:getDimensions())
local WALL_BOT_Q = love.graphics.newQuad(112, 21, 48, 34, WALL_IMG:getDimensions())
local FURN = {
    table    = furnQ( 18,  5, 64, 75), -- dining table with chairs
    fridge   = furnQ( 87, 22, 24, 56),
    hood     = furnQ(119, 17, 24, 21),
    stove    = furnQ(119, 47, 24, 31),
    counter  = furnQ(148, 33, 44, 45), -- doored counter + hanging utensils
    sink     = furnQ(195, 44, 47, 34),
    clock    = furnQ(195, 20, 14, 14),
    painting = furnQ(248, 19, 20, 12),
    cupboard = furnQ(279, 22, 24, 56),
    window   = furnQ(338, 30, 27, 28),
}

local function drawKitchen()
    love.graphics.setColor(1, 1, 1)
    -- Wall band (top), then tiled floor
    for tx = 0, CW, 48 do
        love.graphics.draw(WALL_IMG, WALL_TOP_Q, tx, 0)
        love.graphics.draw(WALL_IMG, WALL_BOT_Q, tx, 32)
    end
    for ty = FLOOR_Y, CH, 36 do
        for tx = 0, CW, 45 do
            love.graphics.draw(FLOOR_IMG, FLOOR_Q, tx, ty)
        end
    end
    -- Wall decorations
    love.graphics.draw(FURN_IMG, FURN.window,   150, 1)
    love.graphics.draw(FURN_IMG, FURN.clock,    190, 8)
    love.graphics.draw(FURN_IMG, FURN.painting, 222, 9)
    -- Furniture along the back wall (bottoms aligned at y=66)
    love.graphics.draw(FURN_IMG, FURN.fridge,    8, 10)
    love.graphics.draw(FURN_IMG, FURN.hood,     38,  6)
    love.graphics.draw(FURN_IMG, FURN.stove,    38, 35)
    love.graphics.draw(FURN_IMG, FURN.counter,  66, 21)
    love.graphics.draw(FURN_IMG, FURN.sink,    114, 32)
    love.graphics.draw(FURN_IMG, FURN.cupboard, 268, 10)
    -- Dining table on the floor, lower-left
    love.graphics.draw(FURN_IMG, FURN.table, 35, 92)
    -- The cat's corner, lower-right: kibble bags + food bowl
    love.graphics.draw(PET_BAG_IMG, BAG_CLOSED_Q, 268, 128)
    love.graphics.draw(PET_BAG_IMG, BAG_OPEN_Q,   292, 132)
    love.graphics.draw(PET_BOWL_IMG, BOWL_Q,      272, 160)
    -- Soft overhead light pool
    love.graphics.setColor(1, 0.97, 0.85, 0.10)
    love.graphics.ellipse("fill", CW/2, FLOOR_Y+60, 110, 50)
    -- Stage label with drop shadow
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.printf("Stage 3 - Kitchen", 1, 3, CW, "center")
    love.graphics.setColor(1, 0.92, 0.75)
    love.graphics.printf("Stage 3 - Kitchen", 0, 2, CW, "center")
end

-- ── Cat rematch drawing (shared Pokemon battle look, systems/battle_visuals) ─
-- The joke: THE PSIPSINI'S INTEREST bar is permanently empty.
local function drawInterestPanel(font)
    BV.drawEnemyPanel("THE PSIPSINI'S  INTEREST", 0, nil, font)
end

function S3:_drawCatBattle()
    local phase = self.phase
    if phase == "catstrips" then
        drawKitchen()
        Sprites.drawCat(self.catX, 95)
        Sprites.drawPlayer(self.px, self.py, self.pdir)
        BV.drawStrips(self.catStripT)
        return
    end
    BV.drawField()
    -- Panels behind the sprites so they don't cover THE CAT
    drawInterestPanel(self.font)
    BV.drawPlayerPanel(self.font)
    -- Player (left, 2x, back turned)
    love.graphics.push()
    love.graphics.translate(30, 78)
    love.graphics.scale(2, 2)
    Sprites.drawPlayer(0, 0, "up")
    love.graphics.pop()
    -- THE CAT (right, 3x): slides in on intro, strolls off at the end
    local catBX = 235
    if phase == "catbattle_intro" then
        catBX = lerp(CW + 50, 235, easeOut(math.min(1, self.catIntroT)))
    elseif phase == "catend" then
        catBX = lerp(235, CW + 70, easeOut(self.catLeaveT))
    end
    love.graphics.push()
    love.graphics.translate(catBX, 30)
    love.graphics.scale(3, 3)
    Sprites.drawCat(0, 0)
    love.graphics.pop()
    if phase == "catbattle_intro" and self.catIntroT > 0.6 then
        local a = math.min(1, (self.catIntroT - 0.6) * 4)
        love.graphics.setColor(0.92, 0.90, 0.85, a)
        love.graphics.rectangle("fill", 20, 68, CW-40, 18)
        love.graphics.setColor(0.20, 0.20, 0.20, a)
        love.graphics.rectangle("line", 20, 68, CW-40, 18)
        if self.font then love.graphics.setFont(self.font) end
        love.graphics.setColor(0.10, 0.10, 0.10, a)
        love.graphics.printf("THE CAT blocks the way!", 0, 72, CW, "center")
    end
    if phase == "catbattle" then
        local q = CAT_ROUNDS[self.catRound]
        if q then BV.drawMenu(q.question, q.choices, self.catSel, self.font) end
    end
    if phase == "catresponse" or phase == "catend" then
        self.dlg:draw(self.font)
    end
end

-- Falling items for the catch minigame
local function drawCatchItem(it)
    if it.kind == "egg" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(EGG_IMG, it.x - 8, it.y - 8)
    elseif it.kind == "milk" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(MILK_IMG, it.x - 8, it.y - 8)
    else -- frying pan: DO NOT catch
        love.graphics.setColor(0.15, 0.15, 0.18)
        love.graphics.circle("fill", it.x, it.y, 6)
        love.graphics.setColor(0.30, 0.30, 0.35)
        love.graphics.circle("fill", it.x, it.y, 4)
        love.graphics.setColor(0.15, 0.15, 0.18)
        love.graphics.rectangle("fill", it.x+5, it.y-1.5, 9, 3)
    end
end

function S3:draw()
    -- Full-screen cat battle phases replace the kitchen scene entirely
    if self.phase == "catstrips" or self.phase == "catbattle_intro" or
       self.phase == "catbattle" or self.phase == "catresponse" or
       self.phase == "catend" then
        self:_drawCatBattle()
        self.trans:draw(CW, CH)
        love.graphics.setColor(1, 1, 1)
        return
    end

    drawKitchen()

    -- Mess items
    for i, m in ipairs(self.mess) do
        if not m.cleaned then
            love.graphics.setColor(m.col[1], m.col[2], m.col[3], 0.85)
            love.graphics.rectangle("fill", m.x, m.y, 18, 14)
            love.graphics.setColor(0.30,0.20,0.10,0.7)
            love.graphics.rectangle("line", m.x, m.y, 18, 14)
            love.graphics.setColor(0.20,0.12,0.06)
            love.graphics.print(m.label:sub(1,6), m.x, m.y+3, 0, 0.55, 0.55)
            if i == self.nearMessIdx then
                love.graphics.setColor(1, 0.90, 0.35)
                love.graphics.printf("[E] Clean", 0, m.y-12, CW, "center")
            end
        else
            -- "cleaned" sparkle
            local t = self.flashT * 3
            love.graphics.setColor(1, 1, 0.70, 0.4 + 0.2*math.sin(t))
            love.graphics.rectangle("fill", m.x+2, m.y+2, 14, 10)
        end
    end

    -- Flour cloud (background visual) — thins out as the mess gets cleaned
    local dirty = #self.mess - self:_cleanedCount()
    if dirty > 0 then
        love.graphics.setColor(1, 0.98, 0.95, 0.25 * (dirty / #self.mess))
        love.graphics.rectangle("fill", 40, 50, 180, 80)
    end

    -- Note (hidden under flour, appears when all cleaned)
    if self.noteVisible and not self.noteRead then
        love.graphics.setColor(1, 0.95, 0.75)
        love.graphics.rectangle("fill", 148, 82, 22, 16)
        love.graphics.setColor(0.60, 0.45, 0.20)
        love.graphics.rectangle("line", 148, 82, 22, 16)
        love.graphics.setColor(0.40, 0.28, 0.10)
        love.graphics.print("Note", 150, 86, 0, 0.6, 0.6)
        if self.nearNote then
            love.graphics.setColor(1, 0.90, 0.35)
            love.graphics.printf("[E] Read Note", 0, 70, CW, "center")
        end
    end

    -- Cookie on counter
    if not self.cookiePicked then
        Sprites.drawCookie(self.cookieX, self.cookieY)
        if self.phase == "exit_ready" then
            love.graphics.setColor(0.80, 1, 0.60)
            love.graphics.printf("Cookie! (walk over)", 0, self.cookieY-10, CW, "center")
        end
    end

    -- Cat (on the cupboards during catch; back at her spot even after
    -- "leaving" in the rematch, because cat)
    local catY = self.phase == "catch" and 24 or 95
    Sprites.drawCat(self.catX, catY, self.catDashing)

    -- Pet-the-cat: prompt + reaction popup
    local interactive = self.phase == "explore" or self.phase == "exit_ready"
    if interactive and self.nearCat and self.petT > 1.2 then
        love.graphics.setColor(1, 0.90, 0.35)
        love.graphics.printf("[E] Pet the cat", 0, 80, CW, "center")
    end
    if self.petT < 1.2 then
        local reactions = {
            "*suspicious stare*",
            "*leans away... but allows it*",
            "*PURRRRRRRR*",
        }
        local txt = reactions[math.min(self.petCount, #reactions)]
        Dialogue.popup(txt, self.catX + 8, 62, self.font)
        if self.petCount >= 3 then
            local a = 1 - self.petT / 1.2
            for i = 0, 2 do
                love.graphics.setColor(1, 0.45, 0.60, a)
                love.graphics.print("<3", self.catX + i*9 - 4,
                    88 - self.petT*20 - i*6, 0, 0.7, 0.7)
            end
        end
    end

    -- Player (during the catch minigame she carries the bowl instead)
    if self.phase == "catch" then
        Sprites.drawPlayer(self.bowlX - 8, 135, "up", true)
        -- Mixing bowl held overhead
        love.graphics.setColor(0.95, 0.92, 0.80)
        love.graphics.arc("fill", self.bowlX, 138, 16, 0, math.pi)
        love.graphics.setColor(0.55, 0.45, 0.30)
        love.graphics.arc("line", self.bowlX, 138, 16, 0, math.pi)
        love.graphics.ellipse("line", self.bowlX, 138, 16, 3)
        -- Falling ingredients (and pans)
        for _, it in ipairs(self.items) do drawCatchItem(it) end
        -- Pan-hit red flash
        if self.panFlash > 0 then
            love.graphics.setColor(1, 0.15, 0.10, self.panFlash * 0.5)
            love.graphics.rectangle("fill", 0, 0, CW, CH)
        end
        -- Hints
        if self.catchT < 4 then
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.printf("Catch the ingredients - NOT the frying pan!", 0, CH-14, CW, "center")
        end
    else
        Sprites.drawPlayer(self.px, self.py, self.pdir,
            self.pmoving and (self.phase == "explore" or self.phase == "exit_ready"))
    end

    -- "!" + white flash when THE CAT ambushes the exit
    if self.phase == "catflash" then
        love.graphics.setColor(0.10, 0.10, 0.10)
        love.graphics.rectangle("fill", self.px+5, self.py-32, 10, 14)
        love.graphics.setColor(1, 0.85, 0.10)
        love.graphics.rectangle("fill", self.px+6, self.py-31, 8, 12)
        love.graphics.setColor(0.10, 0.10, 0.10)
        if self.font then love.graphics.setFont(self.font) end
        love.graphics.print("!", self.px+8, self.py-30)
        if self.catFlashWhite > 0 then
            love.graphics.setColor(1, 1, 1, self.catFlashWhite)
            love.graphics.rectangle("fill", 0, 0, CW, CH)
        end
    end

    -- Progress
    love.graphics.setColor(0.90, 0.85, 0.70)
    if self.phase == "catch" then
        love.graphics.printf("Ingredients: "..self.caught.."/"..CATCH_GOAL, 4, 18, 140, "left")
    else
        local cleaned = self:_cleanedCount()
        local total   = #self.mess
        love.graphics.printf("Mess: "..cleaned.."/"..total.." cleaned", 4, 18, 120, "left")
    end

    -- Exit hint
    if self.phase == "exit_ready" then
        love.graphics.setColor(0.85, 1, 0.65)
        love.graphics.printf("Walk right to the show! -->", 0, CH-12, CW, "center")
    end

    -- Cookie HUD
    love.graphics.setColor(0.85, 0.70, 0.30)
    love.graphics.printf("Cookies: "..Collectibles.count().."/4", CW-70, 2, 68, "right")

    -- Dialogue
    if self.phase == "intro" or self.phase == "catdash" or
       self.phase == "note"  or self.phase == "after_note" or
       self.phase == "bake_intro" or self.phase == "catch_done" then
        self.dlg:draw(self.font)
    end

    self.trans:draw(CW, CH)
    love.graphics.setColor(1,1,1)
end

return S3
