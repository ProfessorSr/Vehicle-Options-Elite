--[[
	Plugin: Spotlights
	Purpose: Tag definitions for Spotlights plugin.
	Last updated: 2026-03-22
]]

local Tags = {}

Tags.Name = "Spotlights"
Tags.Role = "Spotlight"
Tags.Action = nil

Tags.Required = {
    SpotlightLeft_Tag = "VOE_Light_SpotlightLeft",
    SpotlightRight_Tag = "VOE_Light_SpotlightRight",
}

Tags.Optional = {}

Tags.Instructions = {
    "Tag the main left spotlight part with VOE_Light_SpotlightLeft. This part will emit light when the left spotlight is on.",
    "Tag the main right spotlight part with VOE_Light_SpotlightRight. This part will emit light when the right spotlight is on.",
    "Add attachments named SpotlightLeft_Arm, SpotlightLeft_Lamp, SpotlightRight_Arm, SpotlightRight_Lamp to your vehicle for each spotlight you want to use.",
    "Configure keybinds and attachment names in Config.luau.",
}

return Tags
