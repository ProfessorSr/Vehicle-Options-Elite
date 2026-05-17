--[[
	Plugin: Engine
	Purpose: Tag definitions for Engine plugin.
	Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "Engine"

Tags.Role = "Engine"

Tags.Action = nil

Tags.Required = {}

Tags.Optional = {}

Tags.Instructions = {
	"The Engine plugin manages engine state simulation: RPM, temperature, battery, coolant, oil pressure, wear, maintenance, limp mode, and progressive failure.",
	"No part tagging is required. The plugin reads chassis values and Damage plugin state automatically.",
}

-- State values owned by this plugin:
-- Running
-- EngineRPM
-- EngineRPMMaxOverride
-- EngineTemp
-- EngineWear
-- EngineFailed
-- EngineMisfiring
-- BatteryPercent / BatteryVoltage / BatteryLow / AlternatorOn / BatteryCondition
-- CoolantLevel / CoolantPressure / CoolantWarning / CoolantTemp / CoolantLight
-- EngineLimpMode / CheckEngine
-- MaintenanceMilesRemaining / MaintenanceDue
-- OilPressure / OilPressureWarning / OilLevel / OilLight
--
-- It also owns the client/server action:
-- SetRPMHint

return Tags

