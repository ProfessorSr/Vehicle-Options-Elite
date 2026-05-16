local Tags = {}

--[[
	Plugin: Spoiler
	Purpose: Tag definitions for Spoiler plugin.
	Last updated: 2026-03-21
]]

Tags.Name = "Spoiler"

Tags.Role = "Spoiler"

Tags.Action = "ToggleSpoiler"

Tags.Required = {
	Root = "VOE_Spoiler_Root",
	Part = "VOE_Spoiler_Part",
}

Tags.Optional = {
	HingePivotAttachment = "VOE_HingePivot",
	OpenAngleAttribute = "VOE_OpenAngle",
	OpenSpeedAttribute = "VOE_OpenSpeed",
	OpenTorqueAttribute = "VOE_OpenTorque",
	ClickInteraction = "VOE_Click_Spoiler",
}

Tags.Instructions = {
	"Tag the main spoiler part with VOE_Spoiler_Root. This is the part the plugin treats as the hinge-driving root.",
	"Tag any additional spoiler pieces with VOE_Spoiler_Part. These pieces are welded to the root so the full spoiler assembly moves as one unit.",
	"Add an attachment named VOE_HingePivot to the spoiler root exactly where you want the hinge pivot to be. The plugin uses this attachment's position and axis to place the hinge.",
	"Optional: tag a clickable part with VOE_Click_Spoiler if you want click/prompt interaction to toggle the spoiler.",
	"Optional: set VOE_OpenAngle, VOE_OpenSpeed, or VOE_OpenTorque attributes on the spoiler root to override the plugin defaults for this vehicle.",
	"If no VOE_HingePivot attachment is present, the plugin falls back to the root part position and UpVector, which is only a safe fallback and not the preferred setup.",
}

return Tags
