--[[
    Plugin: Reflectors
    Purpose: Tag definitions for Reflectors plugin.
    Last updated: 2026-03-21
]]
local Tags = {}

Tags.Role = "Reflectors"

Tags.Action = nil

Tags.Required = {
    ReflectorLow = { Tag = "VOE_Reflector_Low", Description = "Reflector for low beam" },
    ReflectorHigh = { Tag = "VOE_Reflector_High", Description = "Reflector for high beam" },
    ReflectorBrake = { Tag = "VOE_Reflector_Brake", Description = "Reflector for brake lights" },
    ReflectorReverse = { Tag = "VOE_Reflector_Reverse", Description = "Reflector for reverse lights" },
    ReflectorSignalLeft = { Tag = "VOE_Reflector_SignalLeft", Description = "Reflector for left signal" },
    ReflectorSignalRight = { Tag = "VOE_Reflector_SignalRight", Description = "Reflector for right signal" },
}

Tags.Optional = {}

Tags.Instructions = {
    "Tag reflector parts with VOE_Reflector_Low and VOE_Reflector_High to mirror the state of the corresponding headlights.",
    "Tag brake reflector parts with VOE_Reflector_Brake to mirror the brake light state.",
    "Tag reverse reflector parts with VOE_Reflector_Reverse to mirror the reverse light state.",
    "Tag signal reflector parts with VOE_Reflector_SignalLeft and VOE_Reflector_SignalRight to mirror the left and right turn signal states.",
}

return Tags
