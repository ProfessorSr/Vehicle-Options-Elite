
--[[
	Popups Config - Configuration settings
--]]

local Config = {}

-- Enables or disables this plugin once plugin-level load gating is applied globally.
Config.Enabled = true

-- If true, popup headlights follow headlight state automatically instead of only the popup toggle state.
Config.AutoOnHeadlights = true

-- Per-role hinge settings for the left and right popup assemblies.
Config.Openables = {
	PopupLeft = {
		OpenAngle = 45,
		CloseAngle = 0,
		OpenSpeed = 3.0,
		OpenTorque = 20000,
	},
	PopupRight = {
		OpenAngle = -45,
		CloseAngle = 0,
		OpenSpeed = 3.0,
		OpenTorque = 20000,
	}
}

-- Actions listed here require vehicle power on the client before they are sent to the server.
Config.PowerActions = {
	TogglePopups = true,
}

-- Plugin-owned keybinds exposed through the generic client bridge.
Config.Keybinds = {
	TogglePopups = Enum.KeyCode.P,
}

return Config