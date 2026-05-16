-- Reflectors Config - Profiles for passive reflectors

--[[
	Plugin: Reflectors
	Purpose: Configuration for Reflectors plugin.
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

Config.Reflectors = {
	Low = {
	Color = Color3.fromRGB(255, 255, 200),
},
	High = {
	Color = Color3.fromRGB(255, 255, 255),
},
	Brake = {
	Color = Color3.fromRGB(255, 60, 60),
},
	Reverse = {
	Color = Color3.fromRGB(255, 255, 255),
},
	SignalLeft = {
	Color = Color3.fromRGB(255, 170, 0),
},
	SignalRight = {
	Color = Color3.fromRGB(255, 170, 0),
}
}

return Config
