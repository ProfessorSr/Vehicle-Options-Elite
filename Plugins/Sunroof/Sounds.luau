local Sounds = {
	-- Add sunroof sound events here
}


local function normalizeSoundId(soundId, assetId)
	local value = soundId
	if value == nil or value == "" then
		value = assetId
	end
	if value == nil then
		return ""
	end
	local str = tostring(value)
	if str == "" then
		return ""
	end
	if string.find(str, "rbxassetid://") then
		return str
	end
	return "rbxassetid://" .. str
end

local function applySoundProperties(sound, data)
	local resolvedId = normalizeSoundId(data.SoundId, data.AssetId)
	if resolvedId ~= "" then
		sound.SoundId = resolvedId
	else
		sound.SoundId = ""
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
