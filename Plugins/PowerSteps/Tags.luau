
--[[
	Plugin: PowerSteps
	Purpose: Tag definitions for PowerSteps plugin.
	Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "PowerSteps"

Tags.Role = "PowerSteps"

Tags.Action = nil

Tags.Required = {
    PowerSteps_FL_Root = "VOE_PowerSteps_FL_Root",
    PowerSteps_FL_Part = "VOE_PowerSteps_FL_Part",
    PowerSteps_FR_Root = "VOE_PowerSteps_FR_Root",
    PowerSteps_FR_Part = "VOE_PowerSteps_FR_Part",
    PowerSteps_RL_Root = "VOE_PowerSteps_RL_Root",
    PowerSteps_RL_Part = "VOE_PowerSteps_RL_Part",
    PowerSteps_RR_Root = "VOE_PowerSteps_RR_Root",
    PowerSteps_RR_Part = "VOE_PowerSteps_RR_Part",
}

Tags.Optional = {
	MotorPivot = "VOE_MotorPivot",
	DeployDistance = "VOE_DeployDistance",
	DeployAngle = "VOE_DeployAngleDeg",
	DeployAxis = "VOE_DeployAxis",
}

Tags.Instructions = {
	"Tag each power step root with VOE_PowerSteps_XX_Root (where XX is FL, FR, RL, or RR) and extra pieces with VOE_PowerSteps_XX_Part. Each step deploys independently when its corresponding door opens.",
	"Add an attachment named VOE_MotorPivot to the root if you want to define the exact pivot point for the step's motion.",
	"Optional: set VOE_DeployDistance, VOE_DeployAngleDeg, or VOE_DeployAxis on the root to override the default deployment behavior.",
}

return Tags
