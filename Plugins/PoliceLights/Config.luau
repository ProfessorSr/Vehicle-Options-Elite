--[[
	Plugin: PoliceLights
	Purpose: Configuration for PoliceLights plugin.
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
	Emergency = {
	Brightness = 3.6,
	Range = 30,
	Angle = 95,
	Shadows = false,
	Color = Color3.fromRGB(40, 130, 255), -- Police blue
}
}

Config.BlinkInterval = 0.5

local keybindsModule = script.Parent and script.Parent:FindFirstChild("Keybinds") or script:FindFirstChild("Keybinds")
local Keybinds = keybindsModule and require(keybindsModule) or {}
Config.Keybinds = Keybinds

return Config
