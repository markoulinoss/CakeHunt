-- Dialogue box system, built on top of LUIS's DialogueBox widget.
-- Public API is unchanged from the old hand-rolled version, so every
-- call site (states/*.lua) keeps working untouched:
--   Dialogue.new(sfxPlay) -> d
--   d:start(lines, onDone) / d:advance() / d:update(dt) / d:draw(font) / d:isActive()
local luis = require "systems.luis_instance"

local Dialogue = {}
Dialogue.__index = Dialogue

-- Box geometry mirrors the old canvas-space box (x=4,y=124,w=312,h=52
-- at 320x180), scaled up to the native 960x540 window LUIS draws in.
local BOX_X, BOX_Y, BOX_W, BOX_H = 12, 372, 936, 156

local sharedBox -- one DialogueBox element, reused by every Dialogue instance
                -- (only one state is ever active/visible at a time)

local function lineText(l) return type(l) == "table" and l.text or l end
local function lineSpeaker(l) return type(l) == "table" and l.speaker or nil end

local function ensureBox()
    if sharedBox then return sharedBox end

    -- Only reached once (sharedBox is set below), so create unconditionally:
    -- probing with luis.layerExists prints a spurious error to the console.
    luis.newLayer("dialogue")

    sharedBox = luis.newDialogueBox("", "", 1, 1, 1, 1, {
        boxColor       = {0.08, 0.04, 0.12, 0.93},
        nameBoxColor   = {1.00, 0.80, 0.35, 1},
        textColor      = {1, 1, 1, 1},
        borderRadius   = 6,
        shadowColor    = {0, 0, 0, 0.35},
        shadowOffset   = 4,
        padding        = 16,
        font           = love.graphics.newFont(16),
        nameFont       = love.graphics.newFont(15),
        indicatorColor = {1.00, 0.85, 0.35, 1},
        textSpeed      = 38,
        fadeInDuration = 0.001,
        fadeOutDuration = 0.001,
    })
    sharedBox.position.x, sharedBox.position.y = BOX_X, BOX_Y
    sharedBox.width, sharedBox.height = BOX_W, BOX_H
    sharedBox:hide()

    luis.createElement("dialogue", "DialogueBox", sharedBox)
    luis.disableLayer("dialogue")
    return sharedBox
end

function Dialogue.new(sfxPlay)
    local d = setmetatable({}, Dialogue)
    d.lines     = {}
    d.lineIdx   = 1
    d.active    = false
    d.onDone    = nil
    d.sfxPlay   = sfxPlay or function() end
    d.box       = ensureBox()
    d.lastChar  = 0
    return d
end

function Dialogue:start(lines, onDone)
    self.lines    = lines
    self.lineIdx  = 1
    self.active   = true
    self.onDone   = onDone
    self.lastChar = 0
    luis.enableLayer("dialogue")
    self.box:show()
    local l = lines[1]
    self.box:setText(lineText(l), lineSpeaker(l) or "")
end

function Dialogue:advance()
    if not self.active then return end
    if not self.box.isComplete then
        self.box:showFullText()
        return
    end
    self.lineIdx = self.lineIdx + 1
    if self.lineIdx > #self.lines then
        self.active = false
        self.box:hide()
        luis.disableLayer("dialogue")
        if self.onDone then self.onDone() end
        return
    end
    local l = self.lines[self.lineIdx]
    self.lastChar = 0
    self.box:setText(lineText(l), lineSpeaker(l) or "")
end

-- Actual char-reveal animation runs inside LUIS's global luis.update(dt)
-- loop (main.lua calls it every frame). This just drives the typing
-- tick SFX by watching the box's reveal progress.
function Dialogue:update(dt)
    if not self.active then return end
    local idx = self.box.charIndex or 0
    if idx ~= self.lastChar then
        if idx % 3 == 0 then self.sfxPlay("advance") end
        self.lastChar = idx
    end
end

-- The box draws itself as part of the global luis.draw() pass in
-- main.lua (it lives outside the low-res game canvas), so there is
-- nothing to do here. Kept for API compatibility with existing call sites.
function Dialogue:draw(font) end

function Dialogue:isActive() return self.active end

-- ── Speech bubble popup (canvas space) ───────────────────────────────────────
-- Quick one-liner bubble for NPC re-talk lines, pet reactions, etc.
-- Drawn on the low-res canvas: cx = anchor centre x, y = bubble top.
local CANVAS_W = 320
function Dialogue.popup(text, cx, y, font)
    if not text or text == "" then return end
    if font then love.graphics.setFont(font) end
    local f  = love.graphics.getFont()
    local maxW = 240
    local w  = math.min(f:getWidth(text), maxW) + 12
    local _, wrapped = f:getWrap(text, w - 12)
    local h  = #wrapped * f:getHeight() + 8
    local x  = math.max(4, math.min(CANVAS_W - w - 4, cx - w/2))
    y = math.max(4, y - (h - 16))   -- grow upward if the text wraps

    -- Shadow, box, border (mirrors the main dialogue box palette)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", x+2, y+2, w, h, 3, 3)
    love.graphics.setColor(0.08, 0.04, 0.12, 0.93)
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)
    love.graphics.setColor(1, 0.80, 0.35)
    love.graphics.rectangle("line", x, y, w, h, 3, 3)
    -- Tail pointing at the speaker
    local tx = math.max(x+8, math.min(x+w-8, cx))
    love.graphics.setColor(0.08, 0.04, 0.12, 0.93)
    love.graphics.polygon("fill", tx-4, y+h, tx+4, y+h, tx, y+h+5)
    -- Text
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(text, x + 6, y + 4, w - 12, "center")
    love.graphics.setColor(1, 1, 1)
end

return Dialogue
