--[[
	Plugin: Wipers
	Purpose: Tag definitions for Wipers plugin.
	Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "Wipers"

Tags.Role = "Wipers"

Tags.Action = nil

Tags.Required = {
    Wipers_WiperLeft_Root = "VOE_WiperLeft_Root",
    Wipers_WiperLeft_Part = "VOE_WiperLeft_Part",
    Wipers_WiperRight_Root = "VOE_WiperRight_Root",
    Wipers_WiperRight_Part = "VOE_WiperRight_Part",
    Wipers_RearWiper_Root = "VOE_RearWiper_Root",
    Wipers_RearWiper_Part = "VOE_RearWiper_Part",
    Wipers_HeadlightWiperLeft_Root = "VOE_HeadlightWiperLeft_Root",
    Wipers_HeadlightWiperLeft_Part = "VOE_HeadlightWiperLeft_Part",
    Wipers_HeadlightWiperRight_Root = "VOE_HeadlightWiperRight_Root",
    Wipers_HeadlightWiperRight_Part = "VOE_HeadlightWiperRight_Part",
}

Tags.Optional = {
	HingePivotAttachment = "VOE_HingePivot",
	MinAngleAttribute = "VOE_WiperMinAngle",
	MaxAngleAttribute = "VOE_WiperMaxAngle",
	OpenSpeedAttribute = "VOE_OpenSpeed",
	OpenTorqueAttribute = "VOE_OpenTorque",
}

Tags.Actions = {
	ToggleWipers = {
		Label = "Front windshield wipers",
		ClickInteraction = "VOE_Click_Wipers",
	},
	ToggleRearWiper = {
		Label = "Rear window wiper",
		ClickInteraction = "VOE_Click_RearWiper",
	},
	ToggleHeadlightWipers = {
		Label = "Headlight wipers",
		ClickInteraction = "VOE_Click_HeadlightWipers",
	},
}

Tags.Instructions = {
	"Tag the main left wiper part with VOE_WiperLeft_Root and any extra left wiper pieces with VOE_WiperLeft_Part. The extra pieces are welded to the root so the left wiper moves as one unit.",
	"Tag the main right wiper part with VOE_WiperRight_Root and any extra right wiper pieces with VOE_WiperRight_Part. The extra pieces are welded to the root so the right wiper moves as one unit.",
	"Tag the rear window wiper root with VOE_RearWiper_Root and any extra rear-wiper pieces with VOE_RearWiper_Part. Those extra pieces are welded to the rear wiper root so the rear assembly moves as one unit.",
	"Tag the left headlight wiper root with VOE_HeadlightWiperLeft_Root and the right headlight wiper root with VOE_HeadlightWiperRight_Root. Any extra pieces for each side use the matching _Part tag so each headlight wiper stays welded to its own root.",
	"Add an attachment named VOE_HingePivot to each wiper root exactly where you want that wiper hinge pivot to be. The plugin uses this attachment's position and axis to place the hinge.",
	"Place each VOE_HingePivot attachment carefully. If it is offset or rotated wrong, the wiper will rotate from the wrong location or on the wrong axis.",
	"Optional: tag a clickable part with VOE_Click_Wipers if you want click/prompt interaction to toggle the paired front windshield wipers together.",
	"Optional: tag a clickable part with VOE_Click_RearWiper if you want click/prompt interaction to toggle the rear window wiper by itself.",
	"Optional: tag a clickable part with VOE_Click_HeadlightWipers if you want click/prompt interaction to toggle both headlight wipers together.",
	"Optional: set VOE_WiperMinAngle or VOE_WiperMaxAngle on a wiper root to override parked and swept angles for that specific wiper.",
	"Optional: set VOE_OpenSpeed or VOE_OpenTorque on a wiper root to override servo motion for that specific wiper.",
	"Rain sensing belongs to this plugin. If you enable it in Config.lua, the front wiper group can react to a shared RainDetected state or vehicle attribute without requiring a separate rain-sensing plugin.",
}

return Tags
