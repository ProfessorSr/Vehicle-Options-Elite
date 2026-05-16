--[[
	Plugin: Popups
	Purpose: Tag definitions for Popups plugin.
	Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "Popups"

Tags.Role = "Popups"

Tags.Action = "TogglePopups"

Tags.Required = {
    Popups_PopupLeft_Root = "VOE_PopupLeft_Root",
    Popups_PopupLeft_Part = "VOE_PopupLeft_Part",
    Popups_PopupRight_Root = "VOE_PopupRight_Root",
    Popups_PopupRight_Part = "VOE_PopupRight_Part",
}

Tags.Optional = {
	HingePivotAttachment = "VOE_HingePivot",
	ClickInteraction = "VOE_Click_Popups",
	OpenAngleAttribute = "VOE_OpenAngle",
	OpenSpeedAttribute = "VOE_OpenSpeed",
	OpenTorqueAttribute = "VOE_OpenTorque",
}

Tags.Instructions = {
	"Tag the main left popup part with VOE_PopupLeft_Root and any extra left popup pieces with VOE_PopupLeft_Part. The extra pieces are welded to the root so the left popup moves as one unit.",
	"Tag the main right popup part with VOE_PopupRight_Root and any extra right popup pieces with VOE_PopupRight_Part. The extra pieces are welded to the root so the right popup moves as one unit.",
	"Add an attachment named VOE_HingePivot to each popup root exactly where you want that popup hinge pivot to be. The plugin uses this attachment's position and axis to place the hinge.",
	"Place each VOE_HingePivot attachment carefully. If it is offset or rotated wrong, the popup will rotate from the wrong location or on the wrong axis.",
	"Optional: tag a clickable part with VOE_Click_Popups if you want click/prompt interaction to toggle both popups together.",
	"Optional: set VOE_OpenAngle, VOE_OpenSpeed, or VOE_OpenTorque attributes on popup roots to override the plugin defaults for this vehicle.",
}

return Tags
