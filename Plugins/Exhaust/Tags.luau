--[[
	Plugin: Exhaust
	Purpose: Tag definitions for Exhaust plugin.
	Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "Exhaust"

Tags.Role = "Exhaust"

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

return Tags
