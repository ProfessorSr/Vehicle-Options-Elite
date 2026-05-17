
--[[
    Plugin: Underglow
    Purpose: Tag definitions for Underglow plugin.
    Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "Underglow"

Tags.Role = "Underglow"

Tags.Action = nil

Tags.Required = {
    Underglow_Tag = "VOE_Underglow",
    Underglow_Description = "Neon underglow part (tag for activation)",
}

Tags.Optional = {}

Tags.Instructions = {
    "Tag any part you want to use as neon underglow with VOE_Underglow.",
    "When activated, the part will become Neon and glow with the configured color.",
}

return Tags
