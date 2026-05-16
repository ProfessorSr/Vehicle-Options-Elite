--[[
	Plugin: AmbulanceLights
	Purpose: Configuration for AmbulanceLights plugin.
	Last updated: 2026-03-21
]]


local Config = {}

-- Enables or disables this plugin once plugin-level load gating is applied globally.
Config.Enabled = true

Config.Debug = {
	Enabled = true,
	LogKeybinds = true,
	LogStateChanges = true,
	LogValueSignals = true,
	Verbose = false,
}

Config.Lights = {
	Emergency = {
	Brightness = 3.6,
	Range = 30,
	Angle = 95,
	Shadows = false,
	Color = Color3.fromRGB(255, 255, 255), -- Ambulance white
}
}

Config.BlinkInterval = 0.5

return Config
