--[[
	Plugin: Doors
	Purpose: Keybind defaults for the Doors plugin.
	Last updated: 2026-05-15
]]

local Keybinds = {
	ToggleDoorFL = Enum.KeyCode.Seven,
	ToggleDoorFR = Enum.KeyCode.Eight,
	ToggleDoorRL = Enum.KeyCode.Three,
	ToggleDoorRR = Enum.KeyCode.Four,
	ToggleDoorSL = Enum.KeyCode.Nine,
	ToggleDoorSR = Enum.KeyCode.Zero,
	ToggleGasDoor = Enum.KeyCode.O,

	KeybindMap = {
		ToggleDoorFL = "DoorFL",
		ToggleDoorFR = "DoorFR",
		ToggleDoorRL = "DoorRL",
		ToggleDoorRR = "DoorRR",
		ToggleDoorSL = "DoorSL",
		ToggleDoorSR = "DoorSR",
		ToggleGasDoor = "GasDoor",
	},
}

return Keybinds
