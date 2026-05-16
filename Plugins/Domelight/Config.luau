--
-- V O E   P L U G I N S • Domelight Config
--

local PluginConfig = {
	-- Plugin enabled state
	Enabled = true,
	
	-- Debug settings
	Debug = {
		Enabled = false,
		LogKeybinds = true,
	},
	
	-- Keybinds
	Keybinds = {
		ToggleDomelight = Enum.KeyCode.L,
	},
	
	-- Light profiles
	Lights = {
		Dome = {
			Brightness = 1.2,
			Range = 25,
			Angle = 120,
			Color = Color3.fromRGB(255, 245, 220),
			Shadows = true,
		},
	},
	
	-- Behavior settings
	-- When true: domelight responds to door state AND manual switch
	-- When false: domelight only responds to manual switch
	AutoWithDoors = true,
}

return PluginConfig