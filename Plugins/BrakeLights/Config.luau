--[[
	Plugin: BrakeLights
	Purpose: Configuration for BrakeLights plugin.
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
	Brake = {Brightness = 6.2, Range = 25, Angle = 70, Shadows = false, Color = Color3.fromRGB(255, 60, 60)},
}


Config.AttachmentYawOverrides = {
	Brake = 0, -- Rear-facing lights
}

return Config
