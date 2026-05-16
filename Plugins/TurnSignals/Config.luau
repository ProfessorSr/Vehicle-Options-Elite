--[[
	Plugin: TurnSignals
	Purpose: Configuration for TurnSignals plugin.
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
	SignalLeftRear = 0,
	SignalRightRear = 0,
}

Config.Lights = {
	Signal = {Brightness = 6.5, Range = 30, Angle = 80, Shadows = false, Color = Color3.fromRGB(255, 170, 0)},
}

Config.Keybinds = {
	ToggleSignalLeft = Enum.KeyCode.Z,
	ToggleSignalRight = Enum.KeyCode.C,
	ToggleHazard = Enum.KeyCode.X,
}

return Config
