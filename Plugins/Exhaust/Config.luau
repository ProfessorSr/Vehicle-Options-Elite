--[[
	Plugin: Exhaust
	Purpose: Configuration for Exhaust plugin.
	Last updated: 2026-03-21
]]

local Config = {}

-- Enables or disables this plugin once plugin-level load gating is applied globally.
Config.Enabled = true

-- Debug options for this plugin
Config.Debug = {
	Enabled = true,
	Verbose = false,
}

-- Exhaust pipe motion owned by this plugin.
-- Tag one or more exhaust assemblies, mark the main pipe section as Root and any additional
-- sections as Part, and the plugin will weld the parts to the root and apply a small
-- Motor6D-driven shake based on engine RPM.
Config.ExhaustMotion = {
	Enabled = true,
	AmplitudeStuds = 0.015,
	AmplitudeDegrees = 1.25,
	FrequencyAtIdle = 10,
	FrequencyAtRedline = 28,
	Axis = "X",
	RotateAxis = "Z",
}

return Config
