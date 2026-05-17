
--[[
	Plugin: Hood
	Purpose: Configuration for Hood plugin.
	Last updated: 2026-03-21
]]

local Config = {}

-- Enables or disables this plugin once plugin-level load gating is applied globally.
Config.Enabled = true

-- Target open angle, in degrees, when the hood is fully opened.
Config.OpenAngle = -65

-- Target close angle, in degrees. Usually 0 for fully closed.
Config.CloseAngle = 0

-- Debug settings
Config.Debug = {
	Enabled = true,
	LogKeybinds = true,
}

-- Servo angular speed used when moving the hood hinge.
Config.OpenSpeed = 3.0

-- Maximum servo torque applied to the hood hinge.
Config.OpenTorque = 20000

-- Sounds for this plugin live in Hood/Sounds.luau.
-- Client audio rules consumed by the generic client audio observer.
Config.ClientAudio = {
	-- Play the configured sound when the Hood state changes from true to false.
	{
		Type = "TransitionFalse",
		State = "Hood",
		Sound = "HoodClose",
	}
}

-- Plugin-owned keybinds exposed through the generic client bridge.
local keybindsModule = script.Parent and script.Parent:FindFirstChild("Keybinds") or script:FindFirstChild("Keybinds")
local Keybinds = keybindsModule and require(keybindsModule) or {}
Config.Keybinds = Keybinds


return Config
