--[[
	Plugin: Headlights
	Purpose: Tag definitions for Headlights plugin.
	Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "Headlights"

Tags.Role = "Headlights"

Tags.Action = nil

Tags.Required = {
	DRL_Tag = "VOE_Light_DRL",
	DRL_Description = "Daytime Running Lights (G key — separate toggle)",
	Parking_Tag = "VOE_Light_Parking",
	Parking_Description = "Parking lights (mode 1 — dim amber/white corner lights)",
	Low_Tag = "VOE_Light_Low",
	Low_Description = "Low beam headlights (mode 2)",
	High_Tag = "VOE_Light_High",
	High_Description = "High beam headlights (mode 3)",
	LicensePlate_Tag = "VOE_Light_LicensePlate",
	LicensePlate_Description = "License plate lights (on with mode 1+)",
	ReflectorLow_Tag = "VOE_Reflector_Low",
	ReflectorLow_Description = "Reflector for low beam",
	ReflectorHigh_Tag = "VOE_Reflector_High",
	ReflectorHigh_Description = "Reflector for high beam",
	Taillight_Tag = "VOE_Light_Taillight",
	Taillight_Description = "Taillights (on with parking or higher)",
}

Tags.Optional = {}

Tags.Instructions = {
	"Tag the main DRL part with VOE_Light_DRL. This tag enables daytime running lights.",
	"Tag parking light parts with VOE_Light_Parking. These are used for mode 1.",
	"Tag low beam parts with VOE_Light_Low. These are used for mode 2.",
	"Tag high beam parts with VOE_Light_High. These are used for mode 3.",
	"Tag license plate light parts with VOE_Light_LicensePlate. These are enabled with mode 1+.",
	"Tag taillight parts with VOE_Light_Taillight. These are enabled with parking or higher.",
	"Tag reflector parts with VOE_Reflector_Low and VOE_Reflector_High to mirror the matching headlight state.",
}

return Tags
