--[[
  Plugin: FogLights
  Purpose: Tag definitions for FogLights plugin.
  Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "FogLights"

Tags.Role = "FogLights"

Tags.Action = nil

Tags.Required = {
    Fog_Tag = "VOE_Light_Fog",
    ReflectorFog_Tag = "VOE_Reflector_Fog",
}

Tags.Optional = {}

Tags.Instructions = {
	"Tag the main fog light part with VOE_Light_Fog. This tag tells the plugin which parts to enable for fog lights.",
	"Tag any reflector parts with VOE_Reflector_Fog. These parts mirror the fog light state for visual effects.",
}

return Tags
