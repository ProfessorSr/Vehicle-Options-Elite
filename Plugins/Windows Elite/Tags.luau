
--[[
    Plugin: Windows
    Purpose: Tag definitions for Windows plugin.
    Last updated: 2026-03-21
]]
local Tags = {}

Tags.Name = "Windows"

Tags.Role = "Windows"

Tags.Action = nil

Tags.Required = {
    Windows_WindowFL_Root = "VOE_WindowFL_Root",
    Windows_WindowFL_Part = "VOE_WindowFL_Part",
    Windows_WindowFL_Click = "VOE_Click_WindowFL",
	Windows_WindowFR_Root = "VOE_WindowFR_Root",
    Windows_WindowFR_Part = "VOE_WindowFR_Part",
    Windows_WindowFR_Click = "VOE_Click_WindowFR",
    Windows_WindowRL_Root = "VOE_WindowRL_Root",
    Windows_WindowRL_Part = "VOE_WindowRL_Part",
    Windows_WindowRL_Click = "VOE_Click_WindowRL",
	Windows_WindowRR_Root = "VOE_WindowRR_Root",
	Windows_WindowRR_Part = "VOE_WindowRR_Part",
    Windows_WindowRR_Click = "VOE_Click_WindowRR",
    Windows_RearWindowLeft_Root = "VOE_RearWindowLeft_Root",
    Windows_RearWindowLeft_Part = "VOE_RearWindowLeft_Part",
    Windows_RearWindowLeft_Click = "VOE_Click_RearWindowLeft",
    Windows_RearWindowRight_Root = "VOE_RearWindowRight_Root",
    Windows_RearWindowRight_Part = "VOE_RearWindowRight_Part",
    Windows_RearWindowRight_Click = "VOE_Click_RearWindowRight",
    Windows_RearHatchGlass_Root = "VOE_RearHatchGlass_Root",
    Windows_RearHatchGlass_Part = "VOE_RearHatchGlass_Part",
    Windows_RearHatchGlass_Click = "VOE_Click_RearHatchGlass",
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
    TweenTimeAttribute = "VOE_TweenTime",
}

Tags.AllAction = "ToggleWindowsAll"

Tags.AllClick = "VOE_Click_WindowsAll"

Tags.Instructions = {
    "Tag the main window glass with the matching VOE_Window*_Root tag. The root is the part the plugin moves directly.",
    "Tag any extra window pieces with the matching VOE_Window*_Part tag. These extra pieces are welded to the root so the full glass assembly moves together.",
	"For sliding windows, add an attachment named VOE_WindowFL_Part to the window frame or supporting body part. The sliding motor uses that attachment to determine slide direction and anchor space.",
    "For hinged windows, add an attachment named VOE_HingePivot to the window root exactly where you want the hinge pivot to be. That attachment position and axis define where and how the window rotates.",
    "Optional: tag a clickable part with the matching VOE_Click_Window* tag if you want mouse/proximity interaction for that specific window.",
    "For rear hatch glass, use VOE_RearHatchGlass_Root and VOE_RearHatchGlass_Part exactly the same way. It is owned by the Windows plugin now and uses the same hinge or sliding setup rules.",
    "Optional: set VOE_OpenAngle, VOE_OpenSpeed, or VOE_OpenTorque on hinged window roots to override the plugin config for that one window.",
    "Optional: set VOE_OpenDistance, VOE_OpenAngleDeg, VOE_OpenAngleAxis, or VOE_TweenTime on sliding window roots to override the plugin config for that one window.",
}

return Tags
