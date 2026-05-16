
--[[
	Plugin: Wipers
	Purpose: Configuration for Wipers plugin.
	Last updated: 2026-03-21
]]

local Config = {}

-- Enables or disables this plugin once plugin-level load gating is applied globally.
Config.Enabled = true

-- Actions listed here require vehicle power on the client before they are sent to the server.
Config.PowerActions = {
	ToggleWipers = true,
	ToggleRearWiper = true,
	ToggleHeadlightWipers = true,
}

-- Rain-sensing behavior for the paired front windshield wipers.
-- This stays inside the Wipers plugin because it is just an automatic control mode
-- for the existing front-wiper group, not a separate feature domain.
Config.RainSensing = {
	-- Optional state name that a future rain/weather plugin can publish.
	-- When this BoolValue exists and is true, automatic wiping is allowed.
	-- Optional attribute on the vehicle model used as a fallback signal.
	-- When enabled, rain sensing only affects the main front wipers.
	Enabled = true,
	StateName = "RainDetected",
	AttributeName = "RainDetected",
	AutoAction = "ToggleWipers",
}

-- Time in seconds between sweep direction changes while the wipers are on.
Config.StepTime = 0.4

-- Action-to-role groupings. Each action controls the listed wiper roles together.
Config.Actions = {
	ToggleWipers = {"WiperLeft", "WiperRight"},
	ToggleRearWiper = {"RearWiper"},
	ToggleHeadlightWipers = {"HeadlightWiperLeft", "HeadlightWiperRight"},
}

-- State value names created by this plugin. Each one tracks whether that wiper group is on.
Config.StateValues = {
	ToggleWipers = "Wipers",
	ToggleRearWiper = "RearWiper",
	ToggleHeadlightWipers = "HeadlightWipers",
}

-- Per-role hinge settings for each wiper assembly.
Config.Openables = {
	-- Parked angle, in degrees, for the left wiper.
	-- Fully swept angle, in degrees, for the left wiper.
	-- Servo angular speed used for the left wiper hinge.
	-- Maximum servo torque applied to the left wiper hinge.
	-- Parked angle, in degrees, for the right wiper.
	-- Fully swept angle, in degrees, for the right wiper.
	-- Servo angular speed used for the right wiper hinge.
	-- Maximum servo torque applied to the right wiper hinge.
	-- Parked angle, in degrees, for the rear wiper.
	-- Fully swept angle, in degrees, for the rear wiper.
	-- Servo angular speed used for the rear wiper hinge.
	-- Maximum servo torque applied to the rear wiper hinge.
	-- Parked angle, in degrees, for the left headlight wiper.
	-- Fully swept angle, in degrees, for the left headlight wiper.
	-- Servo angular speed used for the left headlight wiper hinge.
	-- Maximum servo torque applied to the left headlight wiper hinge.
	-- Parked angle, in degrees, for the right headlight wiper.
	-- Fully swept angle, in degrees, for the right headlight wiper.
	-- Servo angular speed used for the right headlight wiper hinge.
	-- Maximum servo torque applied to the right headlight wiper hinge.
	WiperLeft = {
	MinAngle = 5,
	MaxAngle = -75,
	OpenSpeed = 8.0,
	OpenTorque = 12000,
},
	WiperRight = {
	MinAngle = 5,
	MaxAngle = -75,
	OpenSpeed = 8.0,
	OpenTorque = 12000,
},
	RearWiper = {
	MinAngle = 0,
	MaxAngle = 85,
	OpenSpeed = 8.0,
	OpenTorque = 12000,
},
	HeadlightWiperLeft = {
	MinAngle = 0,
	MaxAngle = 60,
	OpenSpeed = 10.0,
	OpenTorque = 9000,
},
	HeadlightWiperRight = {
	MinAngle = 0,
	MaxAngle = 60,
	OpenSpeed = 10.0,
	OpenTorque = 9000,
}
}

-- Plugin-owned keybinds exposed through the generic client bridge.
local keybindsModule = script.Parent and script.Parent:FindFirstChild("Keybinds") or script:FindFirstChild("Keybinds")
local Keybinds = keybindsModule and require(keybindsModule) or {}
Config.Keybinds = Keybinds


return Config
