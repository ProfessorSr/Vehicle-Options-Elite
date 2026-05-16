
--[[
	Plugin: Sunroof
	Purpose: Configuration for Sunroof plugin.
	Last updated: 2026-03-21
]]

local Config = {}

-- Enables or disables this plugin once plugin-level load gating is applied globally.
Config.Enabled = true

-- Target open angle, in degrees, when the sunroof is fully opened.
Config.OpenAngle = -35

-- Target close angle, in degrees. Usually 0 for fully closed.
Config.CloseAngle = 0

-- Servo angular speed used when moving the sunroof hinge.
Config.OpenSpeed = 2.8

-- Maximum servo torque applied to the sunroof hinge.
Config.OpenTorque = 15000

-- Plugin-owned keybinds exposed through the generic client bridge.
local keybindsModule = script:FindFirstChild("Keybinds")
local Keybinds = keybindsModule and require(keybindsModule) or {}
Config.Keybinds = Keybinds


return Config
