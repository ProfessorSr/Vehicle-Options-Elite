--[[
	Plugin: Engine
	Purpose: Tag definitions for Engine plugin.
	Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "Engine"

Tags.Role = "Engine"

Tags.Action = nil

Tags.Required = {
	Exhaust = {
		Root = "VOE_Exhaust_Root",
		Part = "VOE_Exhaust_Part",
	},
}

Tags.Optional = {
	MotorPivot = "VOE_MotorPivot",
	ShakeAxis = "VOE_ShakeAxis",
	ShakeRotateAxis = "VOE_ShakeRotateAxis",
	ShakeAmplitudeStuds = "VOE_ShakeAmplitudeStuds",
	ShakeAmplitudeDegrees = "VOE_ShakeAmplitudeDegrees",
	ShakeFreqIdle = "VOE_ShakeFreqIdle",
	ShakeFreqRedline = "VOE_ShakeFreqRedline",
}

Tags.Instructions = {
	"Tag the main exhaust part with VOE_Exhaust_Root. The plugin creates a Motor6D on this root and shakes it based on current EngineRPM.",
	"Tag any additional exhaust parts with VOE_Exhaust_Part. These parts are welded to the root so the whole exhaust assembly moves together.",
	"Add an attachment named VOE_MotorPivot to the exhaust root if you want to define the exact pivot point for the exhaust shake. If omitted, the root part pivot is used.",
	"Optional: set VOE_ShakeAxis, VOE_ShakeRotateAxis, VOE_ShakeAmplitudeStuds, VOE_ShakeAmplitudeDegrees, VOE_ShakeFreqIdle, or VOE_ShakeFreqRedline on the exhaust root to override the default shake behavior.",
}

-- Running
-- EngineRPM
-- EngineTemp
-- EngineWear
-- BatteryPercent / BatteryVoltage / BatteryLow / AlternatorOn
-- CoolantLevel / CoolantPressure / CoolantWarning
-- EngineLimpMode / CheckEngine / EngineRPMMaxOverride
-- MaintenanceMilesRemaining / MaintenanceDue
-- OilPressure / OilPressureWarning
--
-- It also owns the client/server action:
-- SetRPMHint
--
-- Optional exhaust motion tags:
--   VOE_Exhaust_Root
--     Tag the main part of the exhaust tip/pipe assembly with this. The plugin creates a
--     Motor6D on this root and shakes it based on current EngineRPM.
--   VOE_Exhaust_Part
--     Tag any additional parts that should move with the same exhaust root. These parts are
--     welded to the root so the whole exhaust assembly moves together.
--
-- Optional attachment:
--   VOE_MotorPivot
--     Place this attachment on the exhaust root if you want to define the exact pivot point
--     for the exhaust shake. If omitted, the root part pivot is used.
--
-- Optional attributes on the exhaust root:
--   VOE_ShakeAxis
--   VOE_ShakeRotateAxis
--   VOE_ShakeAmplitudeStuds
--   VOE_ShakeAmplitudeDegrees
--   VOE_ShakeFreqIdle
--   VOE_ShakeFreqRedline

return Tags

