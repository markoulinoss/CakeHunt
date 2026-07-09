local SM = {}
SM.__index = SM

function SM.new()
    return setmetatable({ current = nil, states = {} }, SM)
end

function SM:add(name, state)
    self.states[name] = state
end

function SM:switch(name, ...)
    if self.current and self.current.exit then self.current:exit() end
    self.current = self.states[name]
    assert(self.current, "Unknown state: " .. tostring(name))
    if self.current.enter then self.current:enter(...) end
end

function SM:update(dt)    if self.current and self.current.update    then self.current:update(dt) end end
function SM:draw()        if self.current and self.current.draw      then self.current:draw()     end end
function SM:keypressed(k) if self.current and self.current.keypressed then self.current:keypressed(k) end end
function SM:keyreleased(k)if self.current and self.current.keyreleased then self.current:keyreleased(k) end end
function SM:textinput(t)  if self.current and self.current.textinput  then self.current:textinput(t) end end

return SM
