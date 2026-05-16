--[[
	Headlights Sounds - Sound configuration for headlight-related sounds
--]]

local Sounds = {
	-- Headlight sounds
	HeadlightToggle = {
		SoundId = "rbxassetid://0", -- Replace with actual sound ID
		Volume = 0.5,
		PlaybackSpeed = 1.0,
	},
	DRLToggle = {
		SoundId = "rbxassetid://0", -- Replace with actual sound ID
		Volume = 0.3,
		PlaybackSpeed = 1.0,
	},
}

-- Optional: Setup function to create sounds at runtime
local function setupSounds(parent)
	local soundInstances = {}
	
	for name, config in pairs(Sounds) do
		if type(config) == "table" and config.SoundId then
			local sound = Instance.new("Sound")
			sound.Name = name
			sound.SoundId = config.SoundId
			sound.Volume = config.Volume or 0.5
			sound.PlaybackSpeed = config.PlaybackSpeed or 1.0
			sound.Parent = parent
			soundInstances[name] = sound
		end
	end
	
	return soundInstances
end

return {
	Sounds = Sounds,
	setupSounds = setupSounds,
}
