--[[
	Plugin: PowerSteps
	Purpose: Configuration for PowerSteps plugin.
	Last updated: 2026-03-21
]]


-----------------------------
-- Main Config Table
-----------------------------
local Config = {}

Config.Enabled = true

-- Debug settings
Config.Debug = {
	Enabled = true,
}

-- Per-door deployment settings
-- DeployDistance: studs to offset along DeployAxis (negative = downward on Y)
-- DeployAngle: degrees to rotate when deployed (0 = no rotation)
-- DeployAxis: axis for distance offset ("X", "Y", or "Z")
-- TweenTime: seconds for deploy/retract animation
Config.Doors = {
	FL = { DeployDistance = -1.5, DeployAngle = 0, DeployAxis = "Y", TweenTime = 0.22 },
	FR = { DeployDistance = -1.5, DeployAngle = 0, DeployAxis = "Y", TweenTime = 0.22 },
	RL = { DeployDistance = -1.5, DeployAngle = 0, DeployAxis = "Y", TweenTime = 0.22 },
	RR = { DeployDistance = -1.5, DeployAngle = 0, DeployAxis = "Y", TweenTime = 0.22 },
}

return Config
