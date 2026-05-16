--[[
	Plugin: Spotlights
	Purpose: Tag definitions for Spotlights plugin.
	Last updated: 2026-03-22
]]

local Tags = {}

Tags.Name = "Spotlights"
Tags.Role = "Spotlight"
Tags.Action = nil

Tags.Required = {
    SpotlightLeft_Tag = "VOE_SpotlightLeft_Lamp",
    SpotlightRight_Tag = "VOE_SpotlightRight_Lamp",
}

Tags.Optional = {
    SpotlightLeft_BaseRoot = "VOE_SpotlightLeft_BaseRoot",
    SpotlightLeft_BasePart = "VOE_SpotlightLeft_BasePart",
    SpotlightLeft_ArmRoot = "VOE_SpotlightLeft_ArmRoot",
    SpotlightLeft_ArmPart = "VOE_SpotlightLeft_ArmPart",
    SpotlightLeft_Lamp = "VOE_SpotlightLeft_Lamp",
    SpotlightRight_BaseRoot = "VOE_SpotlightRight_BaseRoot",
    SpotlightRight_BasePart = "VOE_SpotlightRight_BasePart",
    SpotlightRight_ArmRoot = "VOE_SpotlightRight_ArmRoot",
    SpotlightRight_ArmPart = "VOE_SpotlightRight_ArmPart",
    SpotlightRight_Lamp = "VOE_SpotlightRight_Lamp",
    HingePivotAttachment = "VOE_HingePivot",
    MinAngleAttribute = "VOE_MinAngle",
    MaxAngleAttribute = "VOE_MaxAngle",
    RotationStepAttribute = "VOE_RotationStep",
    OpenSpeedAttribute = "VOE_OpenSpeed",
    OpenTorqueAttribute = "VOE_OpenTorque",
}

Tags.Instructions = {
    "Tag the main left spotlight part with VOE_SpotlightLeft_Lamp. This part will emit light when the left spotlight is on.",
    "Tag the main right spotlight part with VOE_SpotlightRight_Lamp. This part will emit light when the right spotlight is on.",
    "For rig-driven spotlight hinges, tag the base root and arm root parts with VOE_SpotlightLeft_BaseRoot / VOE_SpotlightRight_BaseRoot and VOE_SpotlightLeft_ArmRoot / VOE_SpotlightRight_ArmRoot. Each root should also contain a VOE_HingePivot attachment.",
    "If a separate moving segment exists, tag it with VOE_SpotlightLeft_BasePart / VOE_SpotlightRight_BasePart or VOE_SpotlightLeft_ArmPart / VOE_SpotlightRight_ArmPart. The bootstrap will weld each part to its root before creating hinges.",
    "You can also add attachments named SpotlightLeft_Lamp and SpotlightRight_Lamp to define lamp pivot points for the plugin if needed.",
    "Place each attachment on the BasePart that should rotate from that pivot. The attachment’s position defines the pivot point, and the attachment’s axis defines the hinge axis.",
    "Optional: set VOE_MinAngle, VOE_MaxAngle, VOE_RotationStep, VOE_OpenSpeed, or VOE_OpenTorque on each rotating spotlight part to override the plugin config for that part. Segment-specific names like VOE_BaseMinAngle, VOE_ArmMaxAngle, or VOE_LampStepAngle are also supported.",
    "Configure keybinds and attachment names in Config.luau.",
}

return Tags
