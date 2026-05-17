--[[
	Plugin: FogLights
	Purpose: Configuration for FogLights plugin.
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

Config.AttachmentYawOverrides = {
	Fog = 0,
}

Config.Lights = {
	Fog = {Brightness = 2.1, Range = 55, Angle = 90, Shadows = false, Color = Color3.fromRGB(255, 237, 181)},
}

local keybindsModule = script.Parent and script.Parent:FindFirstChild("Keybinds") or script:FindFirstChild("Keybinds")
local Keybinds = keybindsModule and require(keybindsModule) or {}
Config.Keybinds = Keybinds


return Config
