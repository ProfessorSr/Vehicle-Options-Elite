
--[[
	Plugin: Spoiler
	Purpose: Configuration for Spoiler plugin.
	Last updated: 2026-03-21
]]

local Config = {}

-- Enables or disables this plugin once plugin-level load gating is applied globally.
Config.Enabled = true

-- Active or user-controlled spoiler deployment.
Config.OpenAngle = 35

-- Close angle, in degrees. Usually 0 for fully closed.
Config.CloseAngle = 0

Config.OpenSpeed = 2.5

Config.OpenTorque = 18000

local keybindsModule = script.Parent and script.Parent:FindFirstChild("Keybinds") or script:FindFirstChild("Keybinds")
local Keybinds = keybindsModule and require(keybindsModule) or {}
Config.Keybinds = Keybinds


return Config
