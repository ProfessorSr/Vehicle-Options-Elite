
--[[
	Plugin: Fuel
	Purpose: Configuration for Fuel plugin.
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

-- Maximum tank capacity in gallons.
Config.MaxGallons = 18

-- Starting gallons when the vehicle boots. If nil, the tank starts full.
Config.StartingGallons = nil

-- Amount of fuel added by the incremental pump interaction.
Config.RefuelGallonsPerUse = 1.0

-- If true, the gas door must already be open before pump actions are allowed.
Config.RequireGasDoorOpen = true

-- If true, a separate FuelCap plugin/state must report the cap as removed/open before
-- pump actions are allowed.
Config.RequireFuelCapRemoved = true

-- If false, pump actions do nothing while the engine is running.
Config.AllowRefuelWhileEngineOn = false

-- What happens when the tank reaches 0 gallons:
-- "Shutoff" turns the engine off immediately.
-- "Limp" keeps the engine on and raises FuelLimpMode so the Engine plugin can apply the RPM cap.
Config.EmptyBehavior = "Shutoff"

-- RPM ceiling used when EmptyBehavior is "Limp".
Config.EmptyLimpRPMMax = 1400

-- If true, accessories remain on after an empty-tank shutoff.
Config.KeepAccessoryOnWhenEmpty = true

-- Fuel burn while idling with the engine on, expressed as tank-percent per second.
-- The plugin converts this into gallons using MaxGallons.
Config.BurnRateIdlePercent = 0.0015

-- Additional tank-percent-per-second added as throttle/load rises.
Config.BurnRateLoadPercent = 0.015

Config.Actions = {
	RefillFuel = "RefillFuel",
	SetFuelGallons = "SetFuelGallons",
	AddFuelGallons = "AddFuelGallons",
}

return Config
