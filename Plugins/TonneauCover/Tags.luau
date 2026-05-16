
--[[
  Plugin: TonneauCover
  Purpose: Tag definitions for TonneauCover plugin.
  Last updated: 2026-03-21
]]
local Tags = {}

Tags.Role = "TonneauCover"

Tags.Action = "ToggleTonneauCover"

Tags.Required = {
	-- Tag the main moving tonneau piece with this root tag.
	-- The hinge is created on this root part.
	Root = "VOE_TonneauCover_Root",
	-- Tag any extra cover pieces with this part tag.
	-- They are welded to the root so the full cover moves together.
	Part = "VOE_TonneauCover_Part",
}

Tags.Optional = {
	-- Put this attachment exactly where the hinge should pivot.
	HingePivotAttachment = "VOE_HingePivot",
	-- Per-part overrides for motion values.
	OpenAngleAttribute = "VOE_OpenAngle",
	OpenSpeedAttribute = "VOE_OpenSpeed",
	OpenTorqueAttribute = "VOE_OpenTorque",
	-- Optional click/prompt interaction tag.
	ClickInteraction = "VOE_Click_TonneauCover",
}

Tags.Instructions = {
	"Tag the main tonneau cover piece with VOE_TonneauCover_Root. This is the part the plugin treats as the hinge-driving root.",
	"Tag any extra cover pieces with VOE_TonneauCover_Part. These pieces are welded to the root so the full tonneau assembly moves as one unit.",
	"Add an attachment named VOE_HingePivot to the tonneau root exactly where you want the hinge pivot to be. The plugin uses this attachment's position and axis to place the hinge.",
	"Optional: tag a clickable part with VOE_Click_TonneauCover if you want click/prompt interaction to toggle the tonneau cover.",
	"Optional: set VOE_OpenAngle, VOE_OpenSpeed, or VOE_OpenTorque attributes on the tonneau root to override the plugin defaults for this vehicle.",
	"If no VOE_HingePivot attachment is present, the plugin falls back to the root part position and UpVector, which is only a safe fallback and not the preferred setup.",
}

return Tags
