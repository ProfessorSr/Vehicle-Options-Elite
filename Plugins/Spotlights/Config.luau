--[[

-- Configuration for up to 4 spotlights (A-D)
-- Each spotlight has:
--   baseAttachment: Name of the Attachment for the spotlight base pivot
--   armAttachment: Name of the Attachment for the arm base
--   lampAttachment: Name of the Attachment for the lamp head
--   armKey: Keybind for rotating the arm in one direction
--   armClockwiseKey: Keybind for rotating the arm clockwise in the opposite direction
--   lampKey: Keybind for rotating the lamp left/right
--   baseKey: Keybind for rotating the entire spotlight base on the horizontal swivel
--   baseCounterKey: Keybind for rotating the base in the opposite direction
]]
local Config = {}

local keybindsModule = script.Parent and script.Parent:FindFirstChild("Keybinds") or script:FindFirstChild("Keybinds")
local Keybinds = keybindsModule and require(keybindsModule) or {}

-- Enables or disables this plugin
Config.Enabled = true

-- Debug options for this plugin
Config.Debug = {
	Enabled = true,
	LogKeybinds = true,
	LogStateChanges = true,
	LogValueSignals = true,
	Verbose = false,
}

Config.RotationSpeed = 5
Config.RotationTorque = 15000

-- Per-rotating-part motion defaults. These can be overridden on each moving
-- BasePart with VOE_MinAngle, VOE_MaxAngle, VOE_RotationStep, VOE_OpenSpeed,
-- or VOE_OpenTorque attributes. Segment-specific attributes such as
-- VOE_BaseMinAngle or VOE_ArmMaxAngle are also supported.
Config.MotionDefaults = {
	Base = {
		MinAngle = -180,
		MaxAngle = 180,
		StepAngle = 5,
	},
	Arm = {
		MinAngle = -180,
		MaxAngle = 180,
		StepAngle = 5,
	},
	Lamp = {
		MinAngle = -45,
		MaxAngle = 45,
		StepAngle = 5,
	},
}

Config.Spotlights = {
	Left = {
		baseAttachment = "SpotlightLeft_Base",
		armAttachment = "SpotlightLeft_Arm",
		lampAttachment = "SpotlightLeft_Lamp",
		armKey = Keybinds.RotateSpotlightLeftArmUp,
		armClockwiseKey = Keybinds.RotateSpotlightLeftArmDown,
		lampKey = Keybinds.RotateSpotlightLeftLamp,
		baseKey = Keybinds.RotateSpotlightLeftBase,
		baseCounterKey = Keybinds.RotateSpotlightLeftBaseCounter,
		Base = {MinAngle = -180, MaxAngle = 180, StepAngle = 5},
		Arm = {MinAngle = -180, MaxAngle = 180, StepAngle = 5},
		Lamp = {MinAngle = -45, MaxAngle = 45, StepAngle = 5},
	},
	Right = {
		baseAttachment = "SpotlightRight_Base",
		armAttachment = "SpotlightRight_Arm",
		lampAttachment = "SpotlightRight_Lamp",
		armKey = Keybinds.RotateSpotlightRightArmUp,
		armClockwiseKey = Keybinds.RotateSpotlightRightArmDown,
		lampKey = Keybinds.RotateSpotlightRightLamp,
		baseKey = Keybinds.RotateSpotlightRightBase,
		baseCounterKey = Keybinds.RotateSpotlightRightBaseCounter,
		Base = {MinAngle = -180, MaxAngle = 180, StepAngle = 5},
		Arm = {MinAngle = -180, MaxAngle = 180, StepAngle = 5},
		Lamp = {MinAngle = -45, MaxAngle = 45, StepAngle = 5},
	},
}


Config.Keybinds = Keybinds


Config.Lights = {
	Spotlight = {Brightness = 4, Range = 60, Angle = 45, Shadows = true, Color = Color3.fromRGB(255, 255, 230)},
}

return Config
