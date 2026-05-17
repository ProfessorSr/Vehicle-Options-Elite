--[[
	Plugin: TurnSignals
	Purpose: Tag definitions for TurnSignals plugin.
	Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "TurnSignals"

Tags.Role = "TurnSignals"

Tags.Action = nil

Tags.Required = {
	SignalLeft_Tag = "VOE_Light_SignalLeft",
	SignalLeft_Description = "Left signal (generic / main)",
	SignalLeftFront_Tag = "VOE_Light_SignalLeft_Front",
	SignalLeftFront_Description = "Left signal front position",
	SignalLeftRear_Tag = "VOE_Light_SignalLeft_Rear",
	SignalLeftRear_Description = "Left signal rear position",
	SignalLeftSide_Tag = "VOE_Light_SignalLeft_Side",
	SignalLeftSide_Description = "Left signal side position",
	SignalRight_Tag = "VOE_Light_SignalRight",
	SignalRight_Description = "Right signal (generic / main)",
	SignalRightFront_Tag = "VOE_Light_SignalRight_Front",
	SignalRightFront_Description = "Right signal front position",
	SignalRightRear_Tag = "VOE_Light_SignalRight_Rear",
	SignalRightRear_Description = "Right signal rear position",
	SignalRightSide_Tag = "VOE_Light_SignalRight_Side",
	SignalRightSide_Description = "Right signal side position",
}

Tags.Optional = {}

Tags.Instructions = {
	"Tag the main left signal part with VOE_Light_SignalLeft. This tag enables left turn signals.",
	"Tag the main right signal part with VOE_Light_SignalRight. This tag enables right turn signals.",
	"Tag front, rear, and side signal parts with their respective tags for full coverage.",
	"Hazard mode enables both left and right signals simultaneously.",
}

return Tags
