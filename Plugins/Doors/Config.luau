--[[
	Plugin: Doors
	Purpose: Configuration for Doors plugin - handles door opening/closing only.
	Last updated: 2026-03-21
]]

local Config = {}

-- Enables or disables this plugin once plugin-level load gating is applied globally.
Config.Enabled = true

-- Debug settings
Config.Debug = {
	Enabled = true,
	LogKeybinds = true,
}

-- Prevents rapid repeat toggles from fighting each other.
Config.ToggleDebounce = 0.2

-- Sounds for this plugin live in Doors/Sounds.luau.
-- Client audio rules consumed by the generic client observer.
Config.ClientAudio = {
	{
		Type = "TransitionTrue",
		State = "DoorLocked",
		Sound = "DoorLock",
	},
	{
		Type = "TransitionFalse",
		State = "DoorLocked",
		Sound = "DoorUnlock",
	},
	{
		Type = "AnyTrueLoop",
		States = "DoorFL,DoorFR,DoorRL,DoorRR,DoorSL,DoorSR",
		Sound = "DoorChime",
	},
	{
		Type = "AllFalseTransition",
		States = "DoorFL,DoorFR,DoorRL,DoorRR,DoorSL,DoorSR",
		Sound = "DoorClose",
	}
}

-- Per-door motion settings. Hinged doors rotate around a hinge pivot attachment.
-- Sliding doors animate from a frame attachment using a Motor6D.
-- OpenAngle: degrees the door opens (negative = left, positive = right)
-- OpenSpeed: angular speed for hinge movement
-- OpenTorque: servo torque for hinge movement
Config.Presets = {
	DoorFL = {
		Type = "Hinged",
		OpenAngle = 65,
		CloseAngle = 0,
		OpenSpeed = 3.0,
		OpenTorque = 20000,
	},
	DoorFR = {
		Type = "Hinged",
		OpenAngle = 65,
		CloseAngle = 0,
		OpenSpeed = 3.0,
		OpenTorque = 20000,
	},
	DoorRL = {
		Type = "Hinged",
		OpenAngle = -65,
		CloseAngle = 0,
		OpenSpeed = 3.0,
		OpenTorque = 20000,
	},
	DoorRR = {
		Type = "Hinged",
		OpenAngle = 65,
		CloseAngle = 0,
		OpenSpeed = 3.0,
		OpenTorque = 20000,
	},
	DoorSL = {
		Type = "Sliding",
		OpenDistance = -1.4,
		CloseDistance = 0,
		OpenAngleDeg = 0,
		OpenAngleAxis = "Y",
		Speed = 2.8,
		TweenTime = nil,
	},
	DoorSR = {
		Type = "Sliding",
		OpenDistance = 1.4,
		CloseDistance = 0,
		OpenAngleDeg = 0,
		OpenAngleAxis = "Y",
		Speed = 2.8,
		TweenTime = nil,
	},
	GasDoor = {
		Type = "Hinged",
		OpenAngle = 80,
		CloseAngle = 0,
		OpenSpeed = 4.0,
		OpenTorque = 8000,
	}
}

-- Keybinds owned by the door plugin. These are bridged generically to the client.
Config.Keybinds = {
	ToggleDoorFL = Enum.KeyCode.Seven,
	ToggleDoorFR = Enum.KeyCode.Eight,
	ToggleDoorRL = Enum.KeyCode.Three,
	ToggleDoorRR = Enum.KeyCode.Four,
	ToggleDoorSL = Enum.KeyCode.Nine,
	ToggleDoorSR = Enum.KeyCode.Zero,
	ToggleGasDoor = Enum.KeyCode.O,
}

return Config
