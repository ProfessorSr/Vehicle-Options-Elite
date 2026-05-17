--[[
  Plugin: BrakeLights
  Purpose: Tag definitions for BrakeLights plugin.
  Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "BrakeLights"

Tags.Role = "BrakeLights"

Tags.Action = nil

Tags.Required = {
	Brake_Tag = "VOE_Light_Brake",
	Brake_Description = "Brake lights (auto from chassis)",
	ReflectorBrake_Tag = "VOE_Reflector_Brake",
	ReflectorBrake_Description = "Reflector for brake",
}

Tags.Optional = {}

Tags.Instructions = {
	"Tag the main brake light part with VOE_Light_Brake. This tag enables brake lights.",
	"Tag reflector parts with VOE_Reflector_Brake to mirror the brake light state.",
}

return Tags
