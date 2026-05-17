
--[[
	Plugin: Trunk
	Purpose: Configuration for Trunk plugin.
	Last updated: 2026-03-21
]]

local Config = {}

-- Enables or disables this plugin once plugin-level load gating is applied globally.
Config.Enabled = true

-- Target open angle, in degrees, when the trunk is fully opened.
Config.OpenAngle = 60

-- Target close angle, in degrees. Usually 0 for fully closed.
Config.CloseAngle = 0

-- Servo angular speed used when moving the trunk hinge.
Config.OpenSpeed = 3.0

-- Maximum servo torque applied to the trunk hinge.
Config.OpenTorque = 20000

-- Sounds for this plugin live in Trunk/Sounds.luau.
-- Client audio rules consumed by the generic client audio observer.
Config.ClientAudio = {
}

-- Plugin-owned keybinds exposed through the generic client bridge.
local keybindsModule = script.Parent and script.Parent:FindFirstChild("Keybinds") or script:FindFirstChild("Keybinds")
local Keybinds = keybindsModule and require(keybindsModule) or {}
Config.Keybinds = Keybinds


return Config
