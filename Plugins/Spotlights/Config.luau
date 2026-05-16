--[[

-- Configuration for up to 4 spotlights (A-D)
-- Each spotlight has:
--   armAttachment: Name of the Attachment for the arm base
--   lampAttachment: Name of the Attachment for the lamp head
--   armKey: Keybind for rotating the arm (up/down)
--   lampKey: Keybind for rotating the lamp (left/right)
]]
local Config = {}

-- Enables or disables this plugin
Config.Enabled = true

-- Debug options for this plugin
Config.Debug = {
	Enabled = true,
	LogKeybinds = true,
	LogStateChanges = true,
	LogValueSignals = true,
	Verbose = false,
}

Config.Spotlights = {
		Left = {
			armAttachment = "SpotlightLeft_Arm",
			lampAttachment = "SpotlightLeft_Lamp",
			armKey = "Q",
			lampKey = "E",
		},
		Right = {
			armAttachment = "SpotlightRight_Arm",
			lampAttachment = "SpotlightRight_Lamp",
			armKey = "R",
			lampKey = "T",
		},
	}


Config.Keybinds = {
	ToggleSpotlightLeft = Enum.KeyCode.One,
	ToggleSpotlightRight = Enum.KeyCode.Two,
}

Config.Lights = {
	Spotlight = {Brightness = 4, Range = 60, Angle = 45, Shadows = true, Color = Color3.fromRGB(255, 255, 230)},
}

return Config