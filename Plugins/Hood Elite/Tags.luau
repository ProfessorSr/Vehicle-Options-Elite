
--[[
	Plugin: Hood
	Purpose: Tag definitions for Hood plugin.
	Last updated: 2026-03-21
]]

local Tags = {}

Tags.Name = "Hood"

Tags.Role = "Hood"

Tags.Action = "ToggleHood"

Tags.Required = {
	Root = "VOE_Hood_Root",
	Part = "VOE_Hood_Part",
}

Tags.Optional = {
	HingePivotAttachment = "VOE_HingePivot",
	ClickInteraction = "VOE_Click_Hood",
	OpenAngleAttribute = "VOE_OpenAngle",
	OpenSpeedAttribute = "VOE_OpenSpeed",
	OpenTorqueAttribute = "VOE_OpenTorque",
}

Tags.Instructions = {
	"Tag the main hood part with VOE_Hood_Root. This is the part the plugin treats as the hinge-driving root.",
	"Tag any additional hood pieces with VOE_Hood_Part. These pieces are welded to the root so the full hood assembly moves as one unit.",
	"Add an attachment named VOE_HingePivot to the hood root exactly where you want the hinge pivot to be. The plugin uses this attachment's position and axis to place the hinge.",
	"Place the VOE_HingePivot attachment carefully. If it is offset or rotated wrong, the hood will open from the wrong location or on the wrong axis.",
	"Optional: tag a clickable part with VOE_Click_Hood if you want click/prompt interaction to toggle the hood.",
	"Optional: set VOE_OpenAngle, VOE_OpenSpeed, or VOE_OpenTorque attributes on the hood root to override the plugin defaults for this vehicle.",
	"If no VOE_HingePivot attachment is present, the plugin falls back to the root part position and UpVector, which is only a safe fallback and not the preferred setup.",
}

return Tags
