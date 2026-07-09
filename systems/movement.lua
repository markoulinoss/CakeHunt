-- Shared 4-direction top-down player movement, used by every walkable stage.
-- Reads the state's held-key set (s.keys) and writes s.px, s.py, s.pdir and
-- s.pmoving. Diagonals are normalised so they aren't faster than straights.
local Movement = {}

function Movement.step(s, dt, speed, minX, minY, maxX, maxY)
    local dx, dy = 0, 0
    if s.keys["left"]  or s.keys["a"] then dx = -1 end
    if s.keys["right"] or s.keys["d"] then dx =  1 end
    if s.keys["up"]    or s.keys["w"] then dy = -1 end
    if s.keys["down"]  or s.keys["s"] then dy =  1 end
    if dx ~= 0 and dy ~= 0 then dx, dy = dx * 0.707, dy * 0.707 end
    s.pmoving = dx ~= 0 or dy ~= 0
    if     dx < 0 then s.pdir = "left"
    elseif dx > 0 then s.pdir = "right"
    elseif dy < 0 then s.pdir = "up"
    elseif dy > 0 then s.pdir = "down" end
    s.px = math.max(minX, math.min(maxX, s.px + dx * speed * dt))
    s.py = math.max(minY, math.min(maxY, s.py + dy * speed * dt))
end

return Movement
