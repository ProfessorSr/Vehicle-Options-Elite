
--[[
    Plugin: AmbulanceLights
    Purpose: Tag definitions for AmbulanceLights plugin.
    Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "AmbulanceLights"

Tags.Role = "AmbulanceLights"

Tags.Action = nil

Tags.Required = {
    Main_Tag = "VOE_Light_Emergency_Ambulance",
    Main_Description = "Ambulance main",
    Front_Tag = "VOE_Light_Emergency_Ambulance_Front",
    Front_Description = "Ambulance front",
    Side_Tag = "VOE_Light_Emergency_Ambulance_Side",
    Side_Description = "Ambulance side (both)",
    SideLeft_Tag = "VOE_Light_Emergency_Ambulance_SideLeft",
    SideLeft_Description = "Ambulance side left only",
    SideRight_Tag = "VOE_Light_Emergency_Ambulance_SideRight",
    SideRight_Description = "Ambulance side right only",
    Rear_Tag = "VOE_Light_Emergency_Ambulance_Rear",
    Rear_Description = "Ambulance rear",
}

Tags.Optional = {}

Tags.Instructions = {
    "Tag ambulance light parts with their respective tags for full coverage.",
}

return Tags
