
--[[
	Plugin: Sunroof
	Purpose: Tag definitions for Sunroof plugin.
	Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "Sunroof"

Tags.Role = "Sunroof"

Tags.Action = "ToggleSunroof"

Tags.Required = {
	Root = "VOE_Sunroof_Root",
	Part = "VOE_Sunroof_Part",
}

Tags.Optional = {
	HingePivotAttachment = "VOE_HingePivot",
	ClickInteraction = "VOE_Click_Sunroof",
	OpenAngleAttribute = "VOE_OpenAngle",
	OpenSpeedAttribute = "VOE_OpenSpeed",
	OpenTorqueAttribute = "VOE_OpenTorque",
}

Tags.Instructions = {
	"Tag the main sunroof panel with VOE_Sunroof_Root. This is the part the plugin treats as the hinge-driving root.",
	"Tag any extra sunroof pieces with VOE_Sunroof_Part. These pieces are welded to the root so the full sunroof assembly moves as one unit.",
	"Add an attachment named VOE_HingePivot to the sunroof root exactly where you want the hinge pivot to be. The plugin uses this attachment's position and axis to place the hinge.",
	"Optional: tag a clickable part with VOE_Click_Sunroof if you want click/prompt interaction to toggle the sunroof.",
	"Optional: set VOE_OpenAngle, VOE_OpenSpeed, or VOE_OpenTorque attributes on the sunroof root to override the plugin defaults for this vehicle.",
	"If no VOE_HingePivot attachment is present, the plugin falls back to the root part position and UpVector, which is only a safe fallback and not the preferred setup.",
}

return Tags
