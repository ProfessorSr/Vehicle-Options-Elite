--[[
	Plugin: Headlights
	Purpose: Configuration for Headlights plugin.
	Last updated: 2026-03-21
]]

local Config = {}

-- Enables or disables this plugin once plugin-level load gating is applied globally.
Config.Enabled = true

Config.BlinkInterval = 0.5

Config.Debug = {
	Enabled = true,
	LogKeybinds = true,
	LogStateChanges = true,
	LogValueSignals = true,
	Verbose = false,
}

Config.AttachmentYawOverrides = {
	-- Degrees around Y axis; keys match lightListName/profileName values used by mapping.
	High = 0,
	Low = 0,
	Parking = 0,
	DRL = 0,
	LicensePlate = 180,
	Taillight = 180,
}

Config.Lights = {
	DRL = {Brightness = 2.2, Range = 36, Angle = 90, Shadows = false, Color = Color3.fromRGB(255, 245, 230)},
	Parking = {Brightness = 3.2, Range = 14, Angle = 80, Shadows = false, Color = Color3.fromRGB(255, 210, 150)},
	Low = {Brightness = 3.8, Range = 90, Angle = 115, Shadows = true, Color = Color3.fromRGB(255, 244, 214)},
	High = {Brightness = 4.4, Range = 130, Angle = 125, Shadows = true, Color = Color3.fromRGB(245, 245, 255)},
	LicensePlate = {Brightness = 1.0, Range = 12, Angle = 100, Shadows = false, Color = Color3.fromRGB(255, 245, 230)},
	Taillight = {Brightness = 3.2, Range = 20, Angle = 120, Shadows = false, Color = Color3.fromRGB(255, 50, 50)},
}

return Config
