
--[[
	Plugin: Hood
	Purpose: Sound definitions and helpers for Hood plugin.
	Last updated: 2026-03-21
]]

local Sounds = {
	HoodOpen = {
		SoundId = "8646897783",
		Volume = 0.5,
	},
	HoodClose = {
		SoundId = "132523351027438",
		Volume = 0.5,
	},
}

local function normalizeSoundId(soundId)
	if soundId == nil then
		return ""
	end
	local value = tostring(soundId)
	if value == "" then
		return ""
	end
	if string.find(value, "rbxassetid://") then
		return value
	end
	return "rbxassetid://" .. value
end

local function applySoundProperties(sound, data)
	if data.SoundId ~= nil then
		sound.SoundId = normalizeSoundId(data.SoundId)
	end
	if data.Volume ~= nil then
		sound.Volume = data.Volume
	end
	if data.Looped ~= nil then
		sound.Looped = data.Looped
	end
	if data.PlaybackSpeed ~= nil then
		sound.PlaybackSpeed = data.PlaybackSpeed
	end
	if data.RollOffMaxDistance ~= nil then
		sound.RollOffMaxDistance = data.RollOffMaxDistance
	end
	if data.RollOffMinDistance ~= nil then
		sound.RollOffMinDistance = data.RollOffMinDistance
	end
	if data.RollOffMode ~= nil then
		sound.RollOffMode = data.RollOffMode
	end
	if data.EmitterSize ~= nil then
		sound.EmitterSize = data.EmitterSize
	end
end

local function setupSounds(parent)
	if not parent then
		return {}
	end
	local created = {}
	for name, data in pairs(Sounds) do
		if type(data) == "table" then
			local sound = parent:FindFirstChild(name)
			if not sound then
				sound = Instance.new("Sound")
				sound.Name = name
				sound.Parent = parent
			end
			applySoundProperties(sound, data)
			created[name] = sound
		end
	end
	return created
end

Sounds.setupSounds = setupSounds

return Sounds
