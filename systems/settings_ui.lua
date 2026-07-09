-- Settings screen (LUIS layer): volume slider + back button.
-- Opened from either the pause menu or the title screen; remembers
-- which layer to return to when "Back" is pressed.
local luis = require "systems.luis_instance"

local Settings = {}
local built = false
local returnLayer = "pause"

function Settings.build(audio)
    if built then return end
    built = true

    luis.newLayer("settings")

    -- Grid is 48x27 cells; 16-wide elements centre at col 17, 12-wide at 19
    local title = luis.newLabel("SETTINGS", 16, 2, 7, 17, "center")
    luis.createElement("settings", "Label", title)

    local volLabel = luis.newLabel("Volume", 16, 2, 11, 17, "left")
    luis.createElement("settings", "Label", volLabel)

    local volSlider = luis.newSlider(0, 100, math.floor(audio.getVolume() * 100), 16, 2,
        function(v) audio.setVolume(v / 100) end, 13, 17)
    luis.createElement("settings", "Slider", volSlider)

    local backBtn = luis.newButton("Back", 12, 3,
        function()
            luis.disableLayer("settings")
            luis.enableLayer(returnLayer)
        end,
        function() end, 17, 19)
    luis.createElement("settings", "Button", backBtn)

    luis.disableLayer("settings")
end

-- Open the settings layer, hiding `fromLayer` and remembering it so
-- Back returns there.
function Settings.open(fromLayer)
    returnLayer = fromLayer
    luis.disableLayer(fromLayer)
    luis.enableLayer("settings")
end

return Settings
