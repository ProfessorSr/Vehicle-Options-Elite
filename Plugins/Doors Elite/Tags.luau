
--[[
    Plugin: Doors
    Purpose: Tag definitions for Doors plugin.
    Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "Doors"

Tags.Role = "Doors"

Tags.Action = nil

Tags.Required = {
    Doors_DoorFL_Root = "VOE_DoorFL_Root",
	Doors_DoorFL_Part = "VOE_DoorFL_Part",
    Doors_DoorFL_Click = "VOE_Click_DoorFL",
    Doors_DoorFR_Root = "VOE_DoorFR_Root",
    Doors_DoorFR_Part = "VOE_DoorFR_Part",
	Doors_DoorFR_Click = "VOE_Click_DoorFR",
    Doors_DoorRL_Root = "VOE_DoorRL_Root",
    Doors_DoorRL_Part = "VOE_DoorRL_Part",
	Doors_DoorRL_Click = "VOE_Click_DoorRL",
    Doors_DoorRR_Root = "VOE_DoorRR_Root",
    Doors_DoorRR_Part = "VOE_DoorRR_Part",
    Doors_DoorRR_Click = "VOE_Click_DoorRR",
    Doors_DoorSL_Root = "VOE_DoorSL_Root",
    Doors_DoorSL_Part = "VOE_DoorSL_Part",
    Doors_DoorSL_Click = "VOE_Click_DoorSL",
    Doors_DoorSR_Root = "VOE_DoorSR_Root",
    Doors_DoorSR_Part = "VOE_DoorSR_Part",
    Doors_DoorSR_Click = "VOE_Click_DoorSR",
    Doors_GasDoor_Root = "VOE_GasDoor_Root",
    Doors_GasDoor_Part = "VOE_GasDoor_Part",
    Doors_GasDoor_Click = "VOE_Click_GasDoor",
}

Tags.Optional = {
	HingePivotAttachment = "VOE_HingePivot",
	SlideFrameAttachment = "VOE_SlideFrame",
	OpenAngleAttribute = "VOE_OpenAngle",
	OpenSpeedAttribute = "VOE_OpenSpeed",
	OpenTorqueAttribute = "VOE_OpenTorque",
	SlideDistanceAttribute = "VOE_OpenDistance",
	SlideAngleDegAttribute = "VOE_OpenAngleDeg",
	SlideAngleAxisAttribute = "VOE_OpenAngleAxis",
	SlideTweenTimeAttribute = "VOE_TweenTime",
}

Tags.LockAction = "ToggleDoorLock"

Tags.Instructions = {
	"Tag the main door shell with the matching VOE_Door*_Root tag. The root is the part the plugin rotates or slides directly.",
	"Tag any extra door pieces with the matching VOE_Door*_Part tag. These extra pieces are welded to the root so the full door assembly moves together.",
	"For hinged doors, add an attachment named VOE_HingePivot to the door root exactly where you want the hinge pivot to be. That attachment position and axis define where and how the door rotates.",
	"For sliding doors, add an attachment named VOE_SlideFrame to the door frame or supporting body part. The sliding door motor uses that attachment to determine slide direction and anchor space.",
	"Optional: tag a clickable part with the matching VOE_Click_Door* tag if you want mouse/proximity interaction for that specific door.",
	"For the fuel door, use VOE_GasDoor_Root and VOE_GasDoor_Part exactly the same way. It is owned by the Doors plugin now and uses the same hinge setup rules.",
	"Optional: set VOE_OpenAngle, VOE_OpenSpeed, or VOE_OpenTorque on hinged door roots to override the plugin config for that one door.",
	"Optional: set VOE_OpenDistance, VOE_OpenAngleDeg, VOE_OpenAngleAxis, or VOE_TweenTime on sliding door roots to override the plugin config for that one door.",
}

return Tags
