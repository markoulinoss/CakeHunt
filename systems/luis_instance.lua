-- Shared LUIS instance. require()'d from multiple files; Lua's module
-- cache guarantees every caller gets the exact same table, so layers
-- created in one file (pause menu, settings) are visible/controllable
-- from any other (title screen, dialogue box).
local initLuis = require "luis.init"

local luis = initLuis("luis/widgets")
luis.flux = require "luis.3rdparty.flux"
luis.baseWidth, luis.baseHeight = 960, 540

return luis
