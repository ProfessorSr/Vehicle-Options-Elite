
--[[
	Plugin: Windows
	Purpose: Configuration for Windows plugin.
	Last updated: 2026-03-21
]]

local Config = {}

-- Enables or disables this plugin once plugin-level load gating is applied globally.
Config.Enabled = true

-- Window actions require electrical power. The generic client checks these before firing.
Config.PowerActions = {
	ToggleWindowFL = true,
	ToggleWindowFR = true,
	ToggleWindowRL = true,
	ToggleWindowRR = true,
	ToggleRearWindowLeft = true,
	ToggleRearWindowRight = true,
	ToggleWindowsAll = true,
}

-- Per-window seat mapping. The action role links each window action back to the matching entry role
-- so seat-scoped permissions can be built generically by runtime.
Config.SeatScopedActionsBySeatName = {
	DriveSeat = {
	ToggleWindowFL = true,
	ToggleWindowsAll = true,
},
	FRPassSeat = {
	ToggleWindowFR = true,
},
	RLPassSeat = {
	ToggleWindowRL = true,
	ToggleRearWindowLeft = true,
},
	RRPassSeat = {
	ToggleWindowRR = true,
	ToggleRearWindowRight = true,
}
}

-- Motion settings for each window.
-- Mode can be:
--   Sliding: glass rolls up/down using a Motor6D against VOE_SlideFrame.
--   Hinged: glass pops out using a hinge at VOE_HingePivot.
-- OpenDistance controls how far a sliding window moves along the frame attachment axis.
-- OpenAngleDeg and OpenAngleAxis allow a sliding window to tilt while it moves.
-- OpenAngle controls how far a hinged window opens.
-- Speed controls how quickly the movement completes when TweenTime is not explicitly set.
-- TweenTime overrides the calculated duration for sliding windows when provided.
-- OpenTorque applies only to hinged windows.
Config.Presets = {
	WindowFL = {
	Mode = "Sliding",
	OpenDistance = 1.8,
	OpenAngleDeg = 25,
	OpenAngleAxis = "Z",
	Speed = 2.8,
	TweenTime = nil,
},
	WindowFR = {
	Mode = "Sliding",
	OpenDistance = 1.8,
	OpenAngleDeg = -25,
	OpenAngleAxis = "Z",
	Speed = 2.8,
	TweenTime = nil,
},
	WindowRL = {
	Mode = "Sliding",
	OpenDistance = 1.8,
	OpenAngleDeg = 25,
	OpenAngleAxis = "Z",
	Speed = 2.8,
	OpenAngle = 25,
	OpenTorque = 12000,
	TweenTime = nil,
},
	WindowRR = {
	Mode = "Sliding",
	OpenDistance = 1.8,
	OpenAngleDeg = -25,
	OpenAngleAxis = "Z",
	Speed = 2.8,
	OpenAngle = -25,
	OpenTorque = 12000,
	TweenTime = nil,
},
	RearWindowLeft = {
	Mode = "Sliding",
	OpenDistance = 1.2,
	OpenAngleDeg = 0,
	OpenAngleAxis = "Z",
	OpenAngle = 20,
	Speed = 2.8,
	OpenTorque = 12000,
	TweenTime = nil,
},
	RearWindowRight = {
	Mode = "Sliding",
	OpenDistance = 1.2,
	OpenAngleDeg = 0,
	OpenAngleAxis = "Z",
	OpenAngle = -20,
	Speed = 2.8,
	OpenTorque = 12000,
	TweenTime = nil,
}
}

-- Keybinds owned by the window plugin. These are bridged generically to the client.
Config.Keybinds = {
	ToggleWindowFL = Enum.KeyCode.Five,
	ToggleWindowFR = Enum.KeyCode.Six,
	ToggleWindowRL = Enum.KeyCode.Seven,
	ToggleWindowRR = Enum.KeyCode.Eight,
	ToggleWindowsAll = Enum.KeyCode.Comma,
}

return Config
