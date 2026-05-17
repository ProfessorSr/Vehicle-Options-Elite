--[[
  Plugin: ReverseLights
  Purpose: Tag definitions for ReverseLights plugin.
  Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "ReverseLights"

Tags.Role = "ReverseLights"

Tags.Action = nil

Tags.Required = {
  "VOE_Light_Reverse", -- Reverse lights (auto from chassis Gear value)
  "VOE_Reflector_Reverse", -- Reflector for reverse
}

Tags.Optional = {}

Tags.Instructions = {
    "Tag the main reverse light part with VOE_Light_Reverse. This tag enables reverse lights when the chassis Gear value is in reverse.",
    "Tag reflector parts with VOE_Reflector_Reverse to mirror the reverse light state for visual effects.",
}

return Tags
