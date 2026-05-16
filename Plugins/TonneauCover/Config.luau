
--[[
	Plugin: TonneauCover
	Purpose: Configuration for TonneauCover plugin.
	Last updated: 2026-03-21
]]

local Config = {}

-- Enables or disables this plugin once plugin-level load gating is applied globally.
Config.Enabled = true

-- Bed cover / tonneau cover open and close behavior.
-- Open angle, in degrees, when the cover is fully raised.
Config.OpenAngle = 55

-- Close angle, in degrees. Usually 0 for fully closed.
Config.CloseAngle = 0

-- Hinge angular speed used by the servo constraint.
Config.OpenSpeed = 2.2

-- Maximum servo torque applied to the tonneau hinge.
Config.OpenTorque = 18000

-- Plugin-owned keybinds.
Config.Keybinds = {
	ToggleTonneauCover = Enum.KeyCode.V,
}

return Config