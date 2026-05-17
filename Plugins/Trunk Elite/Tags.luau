

--[[
	Plugin: Trunk
	Purpose: Tag definitions for Trunk plugin.
	Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "Trunk"

Tags.Role = "Trunk"

Tags.Action = "ToggleTrunk"

Tags.Required = {
	Root = "VOE_Trunk_Root",
	Part = "VOE_Trunk_Part",
}

Tags.Optional = {
	HingePivotAttachment = "VOE_HingePivot",
	ClickInteraction = "VOE_Click_Trunk",
	OpenAngleAttribute = "VOE_OpenAngle",
	OpenSpeedAttribute = "VOE_OpenSpeed",
	OpenTorqueAttribute = "VOE_OpenTorque",
}

Tags.PulseState = "TrunkPulse"

Tags.Instructions = {
	"Tag the main trunk part with VOE_Trunk_Root. This is the part the plugin treats as the hinge-driving root.",
	"Tag any additional trunk pieces with VOE_Trunk_Part. These pieces are welded to the root so the full trunk assembly moves as one unit.",
	"Add an attachment named VOE_HingePivot to the trunk root exactly where you want the hinge pivot to be. The plugin uses this attachment's position and axis to place the hinge.",
	"Place the VOE_HingePivot attachment carefully. If it is offset or rotated wrong, the trunk will open from the wrong location or on the wrong axis.",
	"Optional: tag a clickable part with VOE_Click_Trunk if you want click/prompt interaction to toggle the trunk.",
	"Optional: set VOE_OpenAngle, VOE_OpenSpeed, or VOE_OpenTorque attributes on the trunk root to override the plugin defaults for this vehicle.",
	"If no VOE_HingePivot attachment is present, the plugin falls back to the root part position and UpVector, which is only a safe fallback and not the preferred setup.",
}

return Tags
