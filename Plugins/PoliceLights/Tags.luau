

--[[
    Plugin: PoliceLights
    Purpose: Tag definitions for PoliceLights plugin.
    Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "PoliceLights"

Tags.Role = "PoliceLights"

Tags.Action = nil

Tags.Required = {
    Main_Tag = "VOE_Light_Emergency_Police",
    Main_Description = "Police main (all positions)",
    Front_Tag = "VOE_Light_Emergency_Police_Front",
    Front_Description = "Police front bar",
    Side_Tag = "VOE_Light_Emergency_Police_Side",
    Side_Description = "Police side (both)",
    SideLeft_Tag = "VOE_Light_Emergency_Police_SideLeft",
    SideLeft_Description = "Police side left only",
    SideRight_Tag = "VOE_Light_Emergency_Police_SideRight",
    SideRight_Description = "Police side right only",
    Rear_Tag = "VOE_Light_Emergency_Police_Rear",
    Rear_Description = "Police rear bar",
}

Tags.Optional = {}

Tags.Instructions = {
    "Tag police light parts with their respective tags for full coverage.",
}

return Tags
