--[[
	Plugin: Seatbelt
	Purpose: Configuration for Seatbelt plugin.
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

Config.Seats = {
	DriverSeatName = "DriveSeat",
	FrontPassengerSeatName = "FRPassSeat",
}

Config.Actions = {
	ToggleSeatbelt = "ToggleSeatbelt",
}

Config.SeatScopedActionsBySeatName = {
	DriveSeat = {
	ToggleSeatbelt = true,
},
	FRPassSeat = {
	ToggleSeatbelt = true,
}
}

Config.Keybinds = {
	ToggleSeatbelt = Enum.KeyCode.U,
}

return Config
