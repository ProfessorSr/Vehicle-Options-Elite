--[[
	Plugin: Engine
	Purpose: Configuration for Engine plugin.
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

-- Engine state simulation owned by this plugin.
-- These values are used if no chassis tune is present or if the tune does not expose them.
Config.EngineState = {
	IdleRPM = 800,
	MaxRPM = 7000,
	SpeedToRPMReferenceMph = 140,
}

-- Engine temperature simulation moved out of shared VehicleStats.
Config.EngineTemp = {
	Enabled = true,
	Ambient = 80,
	Normal = 195,
	Max = 260,
	WarmupRate = 22,
	CooldownRate = 14,
}

-- Engine wear simulation owned by this plugin.
-- EngineWear is a 0-100 shared state value that other systems, HUD elements, or damage logic
-- can read without coupling directly to this plugin.
Config.EngineWear = {
	Enabled = true,
	StartingValue = 100,
	BaseRate = 0.02,
	UpdateRate = 1,
}

Config.BatterySystem = {
	Enabled = true,
	StartingPercent = 100,
	MinVoltage = 11.2,
	MaxVoltage = 14.4,
	IdleChargeRate = 0.75,
	RunningChargeRate = 1.8,
	AccessoryDrainRate = 0.35,
	EngineOffDrainRate = 0.05,
	LowThreshold = 25,
	CriticalThreshold = 10,
}

Config.CoolantSystem = {
	Enabled = true,
	StartingLevel = 100,
	WarningLevel = 25,
	CriticalLevel = 10,
	LeakRate = 0,
	PressureAtIdle = 10,
	PressureAtRedline = 18,
}

Config.LimpMode = {
	Enabled = true,
	MaxRPM = 2800,
	TriggerOnFuelLimp = true,
	TriggerOnLowOilPressure = true,
	TriggerOnCriticalBattery = true,
	TriggerOnCriticalCoolant = true,
	TriggerOnOverheat = true,
	TriggerOnMaintenanceDue = false,
}

Config.Maintenance = {
	Enabled = true,
	StartingMilesRemaining = 5000,
	MilesPerSecondAt60Mph = 1 / 60,
	ServiceDueThreshold = 0,
}

Config.OilPressure = {
	Enabled = true,
	PressureAtIdle = 24,
	PressureAtRedline = 62,
	WarningThreshold = 18,
	CriticalThreshold = 8,
	WearPenaltyScale = 0.35,
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
