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

-- Engine temperature simulation owned by this plugin.
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
	-- Base wear rate per update cycle from normal driving (RPM + throttle + speed)
	BaseRate = 0.02,
	UpdateRate = 1,
	-- Additional wear from running with critical coolant level
	CoolantCriticalWearRate = 0.15,
	-- Additional wear from running with critical oil pressure
	OilCriticalWearRate = 0.12,
	-- Additional wear from overdue maintenance
	MaintenanceOverdueWearRate = 0.05,
	-- Collision damage: how much TotalDamage (from Damage plugin) converts to engine wear
	-- Each point of TotalDamage removes this much from EngineWear
	CollisionWearScale = 0.08,
	-- Overheat wear: extra wear per update when engine is at max temp
	OverheatWearRate = 0.10,
}

-- Progressive failure: as EngineWear drops, engine performance degrades.
Config.ProgressiveFailure = {
	Enabled = true,
	-- Wear threshold where max RPM starts dropping (below this, RPM cap decreases)
	RPMCapStartWear = 75,
	-- At 0 wear, max RPM is reduced to this fraction of normal (e.g., 0.35 = 35%)
	RPMCapMinFraction = 0.35,
	-- Wear threshold where power (throttle effectiveness) starts dropping
	PowerDropStartWear = 60,
	-- At 0 wear, throttle effectiveness is reduced to this fraction
	PowerMinFraction = 0.30,
	-- Wear threshold where misfires begin
	MisfireStartWear = 50,
	-- Misfire probability at 0 wear (per update cycle, 0-1)
	MisfireMaxProbability = 0.35,
	-- Misfire RPM drop range (fraction of current RPM lost during misfire)
	MisfireRPMDropMin = 0.15,
	MisfireRPMDropMax = 0.40,
	-- Misfire duration in seconds
	MisfireDuration = 0.3,
}

-- Engine failure: when EngineWear hits 0
Config.EngineFailure = {
	Enabled = true,
	-- When true, engine cannot be restarted after failure until repaired
	BlockRestartOnFailure = true,
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
	-- Battery condition (health) simulation
	ConditionStartingValue = 100,
	ConditionDegradationRate = 0.0001, -- percent per second of engine runtime
	ConditionDeepDischargeMultiplier = 3, -- degradation multiplier when battery is critically low
}

Config.CoolantSystem = {
	Enabled = true,
	StartingLevel = 100,
	WarningLevel = 25,
	CriticalLevel = 10,
	LeakRate = 0,
	PressureAtIdle = 10,
	PressureAtRedline = 18,
	-- Coolant temperature simulation
	TempAtIdle = 180,
	TempAtRedline = 230,
	TempWarmupRate = 15,
	TempCooldownRate = 10,
	TempWarningThreshold = 230,
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

-- Oil level simulation (separate from oil pressure)
-- Oil level drops over time from engine consumption; low oil level reduces oil pressure and increases wear.
Config.OilSystem = {
	Enabled = true,
	StartingLevel = 100,
	BurnRateIdle = 0.0005, -- percent per second at idle
	BurnRateLoad = 0.003, -- additional percent per second at full load
	LeakRate = 0, -- percent per second passive leak (for damage scenarios)
	WarningLevel = 25,
	CriticalLevel = 10,
}

return Config
