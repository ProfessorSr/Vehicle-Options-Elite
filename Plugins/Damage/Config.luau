
--[[
	Plugin: Damage
	Purpose: Configuration for Damage plugin - handles vehicle damage calculation, visual damage, and part detachment.
	Last updated: 2026-03-21
]]

local Config = {}

-- Enables or disables this plugin once plugin-level load gating is applied globally.
Config.Enabled = true

-- Debug settings
Config.Debug = {
	Enabled = true,
	LogKeybinds = true,
}

--====================================================================
-- Global Damage Settings
--====================================================================

-- Multiplier applied to all damage calculations. Higher = more damage per impact.
Config.DamageMultiplier = 1.0

-- Default HitPoints for any part that doesn't have a zone or attribute override.
Config.DefaultHitPoints = 100

-- Minimum damage dealt per qualifying impact (prevents tiny taps from chipping HP).
Config.MinimumDamage = 1

-- Maximum damage dealt in a single impact (caps extreme collisions).
Config.MaximumDamage = 100

-- Minimum impact speed (studs/sec) required to register as a damaging collision.
Config.MinimumImpactSpeed = 5

-- Cooldown in seconds between damage events on the same part.
Config.ImpactCooldown = 0.1

-- Multiplier applied when the colliding object is heavy (AssemblyMass > 500).
Config.HeavyObjectMultiplier = 2.0

-- If true, the plugin will auto-discover all BaseParts under Body when no tagged parts are found.
Config.AutoDiscoverParts = false

-- Interval in seconds between periodic damage state saves.
Config.SaveInterval = 10

-- Maximum number of entries kept in the damage log.
Config.MaxDamageLogEntries = 100

-- Fraction of parts that must be at 0 HP or detached for the vehicle to be considered destroyed.
Config.DestroyedThreshold = 0.75

--====================================================================
-- Damage Zones
--====================================================================
-- Each zone defines HitPoints and whether parts in that zone can detach.
-- Parts are assigned to zones via the VOE_DamageZone attribute or zone tags.

Config.DamageZones = {
	FrontBumper = {
		HitPoints = 60,
		CanDetach = true,
	},
	RearBumper = {
		HitPoints = 60,
		CanDetach = true,
	},
	Hood = {
		HitPoints = 80,
		CanDetach = true,
	},
	Trunk = {
		HitPoints = 80,
		CanDetach = true,
	},
	Door = {
		HitPoints = 100,
		CanDetach = true,
	},
	Fender = {
		HitPoints = 90,
		CanDetach = true,
	},
	QuarterPanel = {
		HitPoints = 110,
		CanDetach = false,
	},
	Windshield = {
		HitPoints = 50,
		CanDetach = false,
	},
	Headlight = {
		HitPoints = 30,
		CanDetach = true,
	},
	Taillight = {
		HitPoints = 30,
		CanDetach = true,
	},
	Mirror = {
		HitPoints = 20,
		CanDetach = true,
	},
	Grill = {
		HitPoints = 40,
		CanDetach = true,
	},
	Exhaust = {
		HitPoints = 50,
		CanDetach = true,
	},
	Default = {
		HitPoints = 100,
		CanDetach = true,
	},
}

--====================================================================
-- Visual Damage Stages
--====================================================================
-- Stages are evaluated from highest threshold to lowest.
-- When damagePercent >= Threshold, that stage's visuals are applied.
-- ColorShift: RGB delta applied to the original color (negative = darker).
-- DeformScale: XYZ scale multiplier delta applied proportionally to damage.

Config.VisualStages = {
	{
		Name = "Pristine",
		Threshold = 0.0,
		ColorShift = { R = 0, G = 0, B = 0 },
		Material = nil,
		Transparency = nil,
		Reflectance = nil,
		DeformScale = { X = 0, Y = 0, Z = 0 },
	},
	{
		Name = "LightDamage",
		Threshold = 0.15,
		ColorShift = { R = -0.03, G = -0.02, B = -0.01 },
		Material = nil,
		Transparency = nil,
		Reflectance = nil,
		DeformScale = { X = 0.01, Y = 0.005, Z = 0.01 },
	},
	{
		Name = "ModerateDamage",
		Threshold = 0.35,
		ColorShift = { R = -0.08, G = -0.06, B = -0.04 },
		Material = Enum.Material.CorrodedMetal,
		Transparency = nil,
		Reflectance = 0.1,
		DeformScale = { X = 0.03, Y = 0.015, Z = 0.03 },
	},
	{
		Name = "HeavyDamage",
		Threshold = 0.60,
		ColorShift = { R = -0.15, G = -0.12, B = -0.10 },
		Material = Enum.Material.CorrodedMetal,
		Transparency = nil,
		Reflectance = 0.05,
		DeformScale = { X = 0.06, Y = 0.03, Z = 0.06 },
	},
	{
		Name = "CriticalDamage",
		Threshold = 0.85,
		ColorShift = { R = -0.25, G = -0.22, B = -0.20 },
		Material = Enum.Material.DiamondPlate,
		Transparency = 0.3,
		Reflectance = 0.0,
		DeformScale = { X = 0.10, Y = 0.05, Z = 0.10 },
	},
}

--====================================================================
-- Detach Settings
--====================================================================

Config.DetachSettings = {
	-- Whether part detachment is enabled globally.
	Enabled = true,

	-- How long (seconds) detached debris persists in the workspace before being cleaned up.
	DebrisLifetime = 30,
}

--====================================================================
-- Client Audio
--====================================================================
-- Sounds for this plugin live in Damage/Sounds.
-- Client audio rules consumed by the generic client audio observer.

Config.ClientAudio = {
	{
		Type = "AnyTrueLoop",
		States = "VehicleDestroyed",
		Sound = "VehicleDestroyed",
	},
}

--====================================================================
-- Keybinds
--====================================================================
-- Plugin-owned keybinds exposed through the generic client bridge.

local keybindsModule = script.Parent and script.Parent:FindFirstChild("Keybinds") or script:FindFirstChild("Keybinds")
local Keybinds = keybindsModule and require(keybindsModule) or {}
Config.Keybinds = Keybinds


return Config
