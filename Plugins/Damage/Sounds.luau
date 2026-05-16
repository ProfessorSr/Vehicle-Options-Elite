
--[[
	Plugin: Damage
	Purpose: Sound definitions and helpers for Damage plugin.
	Last updated: 2026-03-21
]]

local Sounds = {
	LightImpact = {
		SoundId = "138093376",
		Volume = 0.3,
		RollOffMaxDistance = 80,
		RollOffMinDistance = 5,
	},
	MediumImpact = {
		SoundId = "138093376",
		Volume = 0.6,
		PlaybackSpeed = 0.8,
		RollOffMaxDistance = 120,
		RollOffMinDistance = 5,
	},
	HeavyImpact = {
		SoundId = "138093376",
		Volume = 1.0,
		PlaybackSpeed = 0.6,
		RollOffMaxDistance = 200,
		RollOffMinDistance = 5,
	},
	PartDetach = {
		SoundId = "262816530",
		Volume = 0.7,
		RollOffMaxDistance = 100,
		RollOffMinDistance = 5,
	},
	VehicleDestroyed = {
		SoundId = "",
		Volume = 0.5,
		Looped = false,
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