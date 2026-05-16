-- PuddleLights Config - Light profiles for door puddle lights

--[[
	Plugin: PuddleLights
	Purpose: Configuration for PuddleLights plugin.
	Last updated: 2026-03-21
]]

local Config = {}

-- Enables or disables this plugin once plugin-level load gating is applied globally.
Config.Enabled = true

Config.Debug = {
	Enabled = true,
}

Config.Lights = {
	Puddle = {
		Brightness = 1.4,
		Range = 18,
		Angle = 95,
		Shadows = false,
		Color = Color3.fromRGB(255, 245, 230),
	},
}

return Config
