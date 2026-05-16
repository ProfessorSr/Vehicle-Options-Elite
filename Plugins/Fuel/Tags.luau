--[[
  Plugin: Fuel
  Purpose: Tag definitions for Fuel plugin.
  Last updated: 2026-03-21
]]
local Tags = {}

Tags.Role = "Fuel"

Tags.Action = nil

Tags.Required = {}

Tags.Optional = {}

Tags.Click = {
	PumpRefill = "VOE_Click_FuelPumpRefill",
	PumpAdd = "VOE_Click_FuelPumpAdd",
}

Tags.Instructions = {
	"This plugin manages tank state, fuel consumption, and refueling actions.",
	"Optional: tag a clickable part with VOE_Click_FuelPumpRefill to fill the tank to MaxGallons when requirements are met.",
	"Optional: tag a clickable part with VOE_Click_FuelPumpAdd to add Config.RefuelGallonsPerUse gallons.",
	"Fuel gauge needle tags are defined in Gauges/Tags.lua. Fuel door tags are defined in Doors/Tags.lua.",
	"If RequireGasDoorOpen is true, the Doors plugin state 'GasDoor' must already be open to refuel.",
	"If RequireFuelCapRemoved is true, a separate FuelCap plugin should expose a shared state named FuelCap whose true/open value allows refueling.",
}

-- Fuel gauge needle tags live in Gauges/Tags.lua.
-- Fuel door tags live in Doors/Tags.lua.
--
-- Optional click interaction tags owned here:
-- VOE_Click_FuelPumpRefill
--   Fills the tank to MaxGallons when fuel workflow requirements are met.
-- VOE_Click_FuelPumpAdd
--   Adds Config.RefuelGallonsPerUse gallons.
--
-- If RequireGasDoorOpen is true, the Doors plugin state "GasDoor" must already be open.
-- If RequireFuelCapRemoved is true, a separate FuelCap plugin should expose a shared
-- state named FuelCap whose true/open value allows refueling.

return Tags

