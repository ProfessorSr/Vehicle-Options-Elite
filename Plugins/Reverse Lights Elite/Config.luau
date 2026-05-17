-- ReverseLights Config - Light profiles and yaw override

--[[
	Plugin: ReverseLights
	Purpose: Configuration for ReverseLights plugin.
	Last updated: 2026-03-21
]]


local Config = {}
-- Enables or disables this plugin once plugin-level load gating is applied globally.
Config.Enabled = true

-- Debug options for this plugin

Config.Debug = {
	Enabled = true,
	LogKeybinds = true,
	LogStateChanges = true,
	LogValueSignals = true,
	Verbose = false,
}

Config.Lights = {
	Reverse = {
		Color = Color3.fromRGB(255, 255, 255),
		Shadows = true,
	},
	ReflectorReverse = {
		Color = Color3.fromRGB(255, 255, 255),
	},
}

return Config
