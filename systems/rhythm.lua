-- 4-lane falling-arrow rhythm minigame
-- Arrows fall from the top of each lane toward a hit zone near the bottom.
-- Press the matching key as the arrow crosses the zone for Perfect/Good timing.
local Rhythm = {}
Rhythm.__index = Rhythm

local LANES = {"left", "up", "down", "right"}
local SYM   = {left="<", up="^", down="v", right=">"}
local COL   = {
    left  = {0.45, 1.00, 0.65},
    up    = {0.45, 0.80, 1.00},
    down  = {1.00, 0.50, 0.70},
    right = {1.00, 0.90, 0.35},
}
local KEY_TO_LANE = {left="left", up="up", down="down", right="right"}

local CW        = 320
local FIELD_TOP = 22
local HIT_Y     = 110
local LANE_W    = 40

local PERFECT_WIN = 0.07  -- seconds from hitTime
local GOOD_WIN     = 0.16
local MISS_WIN     = 0.26  -- beyond this, note auto-misses

function Rhythm.new(opts)
    opts = opts or {}
    local r = setmetatable({}, Rhythm)
    r.total         = opts.total or 16
    r.travelTime    = opts.travelTime or 1.3
    r.spawnInterval = opts.spawnInterval or 0.55
    r.sfxPlay       = opts.sfxPlay or function() end
    r.active        = false
    return r
end

function Rhythm:start(onWin)
    self.active     = true
    self.onWin      = onWin
    self.t          = 0
    self.spawned    = 0
    self.judged     = 0
    self.nextSpawn  = 0.4
    self.notes      = {}
    self.perfect    = 0
    self.good       = 0
    self.miss       = 0
    self.combo      = 0
    self.maxCombo   = 0
    self.feedback   = nil
    self.feedTimer  = 0
    self.flashLane  = nil
    self.flashTimer = 0
end

function Rhythm:_spawn()
    local lane = LANES[love.math.random(#LANES)]
    table.insert(self.notes, {lane=lane, spawnTime=self.t, hitTime=self.t+self.travelTime, judged=false})
    self.spawned = self.spawned + 1
end

function Rhythm:_registerHit(grade)
    self.judged = self.judged + 1
    if grade == "perfect" then
        self.perfect = self.perfect + 1
        self.combo   = self.combo + 1
    elseif grade == "good" then
        self.good  = self.good + 1
        self.combo = self.combo + 1
    end
    if self.combo > self.maxCombo then self.maxCombo = self.combo end
    self.feedback, self.feedTimer = grade, 0.35
end

function Rhythm:_registerMiss()
    self.judged    = self.judged + 1
    self.miss      = self.miss + 1
    self.combo     = 0
    self.feedback, self.feedTimer = "miss", 0.35
    self.sfxPlay("miss")
end

function Rhythm:update(dt)
    if not self.active then return end
    self.t = self.t + dt

    if self.feedTimer > 0 then
        self.feedTimer = self.feedTimer - dt
        if self.feedTimer <= 0 then self.feedback = nil end
    end
    if self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
        if self.flashTimer <= 0 then self.flashLane = nil end
    end

    if self.spawned < self.total and self.t >= self.nextSpawn then
        self:_spawn()
        self.nextSpawn = self.t + self.spawnInterval
    end

    for i = #self.notes, 1, -1 do
        local n = self.notes[i]
        if not n.judged and self.t > n.hitTime + MISS_WIN then
            n.judged = true
            self:_registerMiss()
            table.remove(self.notes, i)
        elseif n.judged then
            table.remove(self.notes, i)
        end
    end

    if self.active and self.judged >= self.total then
        self.active = false
        local stats = {perfect=self.perfect, good=self.good, miss=self.miss, maxCombo=self.maxCombo}
        if self.onWin then self.onWin(stats) end
    end
end

function Rhythm:keypressed(key)
    if not self.active then return end
    local lane = KEY_TO_LANE[key]
    if not lane then return end
    self.flashLane, self.flashTimer = lane, 0.15

    local bestIdx, bestDiff = nil, math.huge
    for i, n in ipairs(self.notes) do
        if n.lane == lane and not n.judged then
            local diff = math.abs(self.t - n.hitTime)
            if diff < bestDiff then bestDiff, bestIdx = diff, i end
        end
    end
    if not bestIdx then return end

    local n = self.notes[bestIdx]
    if bestDiff <= PERFECT_WIN then
        n.judged = true
        self.sfxPlay("hit")
        self:_registerHit("perfect")
    elseif bestDiff <= GOOD_WIN then
        n.judged = true
        self.sfxPlay("hit")
        self:_registerHit("good")
    end
    -- pressed too early/late relative to any note: ignored, no penalty
end

function Rhythm:draw(cx, cy, font)
    cx = cx or 160
    local fieldX0 = cx - (#LANES * LANE_W) / 2

    if font then love.graphics.setFont(font) end
    love.graphics.setColor(1, 0.9, 0.35)
    love.graphics.printf("DANCE BATTLE!", 0, FIELD_TOP - 16, CW, "center")

    love.graphics.setColor(0.85, 0.85, 0.85)
    love.graphics.printf("Perfect:"..self.perfect.."  Good:"..self.good.."  Miss:"..self.miss,
        0, FIELD_TOP - 6, CW, "center")

    local fieldH = (HIT_Y - FIELD_TOP) + 14

    -- lane field background: vertical gradient, darker near the top
    local bgSteps = 5
    for i = 0, bgSteps-1 do
        local t = i / (bgSteps-1)
        love.graphics.setColor(0.08+0.05*t, 0.06+0.04*t, 0.14+0.06*t, 0.88)
        love.graphics.rectangle("fill", fieldX0, FIELD_TOP + (fieldH/bgSteps)*i,
            LANE_W * #LANES, fieldH/bgSteps + 1)
    end

    -- per-lane tint wash so each column reads as its own color
    for i, lane in ipairs(LANES) do
        local x = fieldX0 + (i - 1) * LANE_W
        local c = COL[lane]
        love.graphics.setColor(c[1], c[2], c[3], 0.06)
        love.graphics.rectangle("fill", x, FIELD_TOP, LANE_W, fieldH)
    end

    -- lane separators
    love.graphics.setColor(1, 1, 1, 0.15)
    for i = 0, #LANES do
        local x = fieldX0 + i * LANE_W
        love.graphics.line(x, FIELD_TOP, x, HIT_Y + 14)
    end

    -- hit zone bar (per lane) with pulsing glow ring
    for i, lane in ipairs(LANES) do
        local x = fieldX0 + (i - 1) * LANE_W
        local c = COL[lane]
        local active = self.flashLane == lane
        local pulse = 0.5 + 0.5*math.sin(self.t * 6)
        if active then
            love.graphics.setColor(c[1], c[2], c[3], 0.35)
            love.graphics.rectangle("fill", x, HIT_Y - 9, LANE_W, 18)
        end
        love.graphics.setColor(c[1], c[2], c[3], active and 0.95 or (0.30 + 0.10*pulse))
        love.graphics.rectangle("fill", x + 2, HIT_Y - 5, LANE_W - 4, 10)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.rectangle("line", x + 2, HIT_Y - 5, LANE_W - 4, 10)
        love.graphics.setColor(0.10, 0.10, 0.10)
        love.graphics.printf(SYM[lane], x, HIT_Y - 4, LANE_W, "center")
    end

    -- falling notes: glow trail + rounded diamond head
    for _, n in ipairs(self.notes) do
        if not n.judged then
            local laneIdx
            for i, l in ipairs(LANES) do if l == n.lane then laneIdx = i; break end end
            local x = fieldX0 + (laneIdx - 1) * LANE_W + LANE_W/2
            local progress = (self.t - n.spawnTime) / self.travelTime
            local y = FIELD_TOP + progress * (HIT_Y - FIELD_TOP)
            local c = COL[n.lane]

            -- trailing glow above the note
            love.graphics.setColor(c[1], c[2], c[3], 0.18)
            love.graphics.rectangle("fill", x - 12, math.max(FIELD_TOP, y-22), 24, 18)

            -- outer glow disc
            love.graphics.setColor(c[1], c[2], c[3], 0.30)
            love.graphics.circle("fill", x, y, 11)
            -- diamond note body
            love.graphics.setColor(c[1], c[2], c[3])
            love.graphics.polygon("fill", x, y-8, x+8, y, x, y+8, x-8, y)
            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.polygon("line", x, y-8, x+8, y, x, y+8, x-8, y)
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.printf(SYM[n.lane], x-12, y-5, 24, "center")
        end
    end

    if self.feedback then
        local col = (self.feedback == "perfect") and {1, 0.9, 0.3}
                 or (self.feedback == "good")    and {0.5, 1, 0.6}
                 or {1, 0.4, 0.4}
        love.graphics.setColor(col[1], col[2], col[3], math.max(0, self.feedTimer / 0.35))
        love.graphics.printf(self.feedback:upper(), 0, HIT_Y + 18, CW, "center")
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Combo x"..self.combo, 0, HIT_Y + 30, CW, "center")

    local barW = LANE_W * #LANES
    love.graphics.setColor(0.25, 0.25, 0.25)
    love.graphics.rectangle("fill", fieldX0, HIT_Y + 42, barW, 6)
    love.graphics.setColor(0.4, 1, 0.5)
    love.graphics.rectangle("fill", fieldX0, HIT_Y + 42, barW * (self.judged / self.total), 6)
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.rectangle("line", fieldX0, HIT_Y + 42, barW, 6)

    love.graphics.setColor(0.65, 0.65, 0.65)
    love.graphics.printf("Hit the arrow key as it crosses the bar!", 0, HIT_Y + 52, CW, "center")
    love.graphics.setColor(1, 1, 1)
end

return Rhythm
