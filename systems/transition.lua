local Transition = {}
Transition.__index = Transition

function Transition.new()
    return setmetatable({ alpha=0, mode="none", timer=0, duration=0.5, onDone=nil }, Transition)
end

function Transition:fadeOut(cb, dur)
    self.mode     = "out"
    self.alpha    = 0
    self.timer    = 0
    self.duration = dur or 0.5
    self.onDone   = cb
end

function Transition:fadeIn(dur)
    self.mode     = "in"
    self.alpha    = 1
    self.timer    = 0
    self.duration = dur or 0.5
end

function Transition:update(dt)
    if self.mode == "none" then return end
    self.timer = self.timer + dt
    local t = math.min(self.timer / self.duration, 1)
    if self.mode == "out" then
        self.alpha = t
        if t >= 1 and self.onDone then
            local cb = self.onDone
            self.onDone = nil
            self.mode = "done"
            cb()
        end
    elseif self.mode == "in" then
        self.alpha = 1 - t
        if t >= 1 then self.mode = "none" end
    end
end

function Transition:draw(W, H)
    if self.alpha <= 0 then return end
    love.graphics.setColor(0, 0, 0, self.alpha)
    love.graphics.rectangle("fill", 0, 0, W or 320, H or 180)
    love.graphics.setColor(1, 1, 1)
end

function Transition:isActive() return self.mode == "out" or self.mode == "done" end

return Transition
