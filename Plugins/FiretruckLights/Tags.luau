--[[
    Plugin: FiretruckLights
    Purpose: Tag definitions for FiretruckLights plugin.
    Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "FiretruckLights"

Tags.Role = "FiretruckLights"

Tags.Action = nil

Tags.Required = {
    Main_Tag = "VOE_Light_Emergency_Firetruck",
    Main_Description = "Firetruck main",
    Front_Tag = "VOE_Light_Emergency_Firetruck_Front",
    Front_Description = "Firetruck front",
    Side_Tag = "VOE_Light_Emergency_Firetruck_Side",
    Side_Description = "Firetruck side (both)",
    SideLeft_Tag = "VOE_Light_Emergency_Firetruck_SideLeft",
    SideLeft_Description = "Firetruck side left only",
    SideRight_Tag = "VOE_Light_Emergency_Firetruck_SideRight",
    SideRight_Description = "Firetruck side right only",
    Rear_Tag = "VOE_Light_Emergency_Firetruck_Rear",
    Rear_Description = "Firetruck rear",
}

Tags.Optional = {}

Tags.Instructions = {
    "Tag firetruck light parts with their respective tags for full coverage.",
}

return Tags
