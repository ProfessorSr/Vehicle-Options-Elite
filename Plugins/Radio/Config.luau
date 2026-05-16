local Config = {}

Config.Enabled = true
Config.DefaultVolume = 0.5
Config.AutoPlay = true
Config.Shuffle = true

local keybindsModule = script.Parent and script.Parent:FindFirstChild("Keybinds") or script:FindFirstChild("Keybinds")
local Keybinds = keybindsModule and require(keybindsModule) or {}
Config.Keybinds = Keybinds


return Config
