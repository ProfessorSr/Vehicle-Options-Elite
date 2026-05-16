
--[[
    Plugin: PuddleLights
    Purpose: Tag definitions for PuddleLights plugin.
    Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "PuddleLights"

Tags.Role = "PuddleLights"

Tags.Action = nil

Tags.Required = {
    PuddleFL_Tag = "VOE_Light_PuddleFL",
    PuddleFR_Tag = "VOE_Light_PuddleFR",
    PuddleRL_Tag = "VOE_Light_PuddleRL",
    PuddleRR_Tag = "VOE_Light_PuddleRR",
    -- Legacy tags (fallback if per-door tags not found)
    PuddleLeft_Tag = "VOE_Light_PuddleLeft",
    PuddleRight_Tag = "VOE_Light_PuddleRight",
}

Tags.Optional = {}

Tags.Instructions = {
    "Tag each puddle light part with the matching per-door tag: VOE_Light_PuddleFL, VOE_Light_PuddleFR, VOE_Light_PuddleRL, or VOE_Light_PuddleRR.",
    "Each puddle light activates independently when its corresponding door opens.",
    "Legacy: VOE_Light_PuddleLeft and VOE_Light_PuddleRight are still supported as fallbacks (all left doors share one light, all right doors share one).",
}

return Tags
