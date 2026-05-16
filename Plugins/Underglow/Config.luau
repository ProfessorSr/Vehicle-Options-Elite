--[[
	Underglow Config - Profile for neon underglow
--]]

local Config = {}

-- Enables or disables this plugin once plugin-level load gating is applied globally.
Config.Enabled = true

-- Debug options for this plugin
Config.Debug = {
	Enabled = true,
	LogKeybinds = true,
	LogStateChanges = true,
	LogValueSignals = true,
	Verbose = false,
}

-- Underglow Mode: "Single" or "Multi"
-- "Single" = One solid color
-- "Multi" = Cycles through colors (rainbow effect)
Config.Mode = "Multi"

-- Single color settings (used when Mode = "Single")
Config.SingleColor = {
	Color = Color3.fromRGB(0, 200, 255), -- Cyan
}

-- Multi color settings (used when Mode = "Multi")
Config.MultiColor = {
	-- Color range: cycle between these colors
	-- You can add as many colors as you want
	Colors = {
		Color3.fromRGB(255, 0, 0),    -- Red
		Color3.fromRGB(255, 127, 0),  -- Orange
		Color3.fromRGB(255, 255, 0),  -- Yellow
		Color3.fromRGB(0, 255, 0),    -- Green
		Color3.fromRGB(0, 255, 255),  -- Cyan
		Color3.fromRGB(0, 127, 255),  -- Blue
		Color3.fromRGB(127, 0, 255),  -- Purple
		Color3.fromRGB(255, 0, 255),  -- Magenta
	},
	-- How fast the colors cycle (seconds per full cycle)
	CycleSpeed = 24.0,
	-- "Solid" = stay on each color, "Fade" = smooth transition between colors
	TransitionStyle = "Fade",
}

-- Common settings for both modes
Config.Underglow = {
	Brightness = 2.2,
	Range = 8,
}

return Config
