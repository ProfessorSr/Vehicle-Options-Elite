--
-- V O E   P L U G I N S • Seating Config
--

local PluginConfig = {
	-- Plugin enabled state
	Enabled = true,
	
	-- Debug settings
	Debug = {
		Enabled = false,
		LogKeybinds = true,
	},

	-- Keybinds
	Keybinds = {},

	-- Seat and entry metadata
	-- DriverRole determines which door the driver uses by default
	-- AuthorizationWindowSeconds is how long a seat entry/exit authorization stays valid
	-- MaxEnterDistance limits how close a character must be to a matching open door
	-- SeatByRole maps a door role to the seat that door should authorize
	-- RoleBySeatName maps a seat name back to its matching door role
	-- ExitDirectionByRole controls which side of the seat a character exits on
	SeatAccess = {
		DriverRole = "DoorFL",
		AuthorizationWindowSeconds = 1.0,
		MaxEnterDistance = 10,
		SeatByRole = {
			DoorFR = "FRPassSeat",
			DoorRL = "RLPassSeat",
			DoorRR = "RRPassSeat",
		},
		RoleBySeatName = {
			DriveSeat = "DoorFL",
			FRPassSeat = "DoorFR",
			RLPassSeat = "DoorRL",
			RRPassSeat = "DoorRR",
		},
		ExitDirectionByRole = {
			DoorFL = -1,
			DoorFR = 1,
			DoorRL = -1,
			DoorRR = 1,
			DoorSL = -1,
			DoorSR = 1,
		},
	},
	
	-- Seat lock settings
	-- When enabled, prevents passengers from entering certain seats
	SeatLock = {
		Enabled = true,
		LockAllByDefault = false,
		LockedSeats = {}, -- e.g., {"FRPassSeat", "RRPassSeat"}
	},
}

local keybindsModule = script.Parent and script.Parent:FindFirstChild("Keybinds") or script:FindFirstChild("Keybinds")
local Keybinds = keybindsModule and require(keybindsModule) or {}
PluginConfig.Keybinds = Keybinds

return PluginConfig