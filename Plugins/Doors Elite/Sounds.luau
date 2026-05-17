local Sounds = {
	DoorChime = { SoundId = "rbxassetid://87411133131204", Volume = 0.25, Looped = true },
	DoorLock = { SoundId = "rbxassetid://132523351027438", Volume = 0.45 },
	DoorUnlock = { SoundId = "rbxassetid://132523351027438", Volume = 0.45 },
	DoorClose = { SoundId = "", Volume = 0.45 },
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
