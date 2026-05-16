-- Sounds ModuleScript
local Sounds = {}

-- Configuration
Sounds.Config = {
	WindVolume = 0.6,    -- Volume of wind at 200 km/h
	BodyVolume = 0.1,    -- Volume of body sounds at 200 km/h
}

-- Sound references
local wind = nil
local body = nil
local eq = nil

-- Creates and returns the wind and body sounds
function Sounds.Create(parent)
	-- Wind Sound
	wind = parent:FindFirstChild("WindSound") or Instance.new("Sound")
	wind.Name = "WindSound"
	wind.RollOffMaxDistance = 100
	wind.RollOffMinDistance = 10
	wind.RollOffMode = Enum.RollOffMode.InverseTapered
	wind.Looped = true
	wind.SoundId = "rbxassetid://9082987847"
	wind.Volume = 0
	wind.Parent = parent
	
	-- Equalizer for wind
	eq = wind:FindFirstChild("EQ") or Instance.new("EqualizerSoundEffect")
	eq.Name = "EQ"
	eq.HighGain = 0
	eq.LowGain = 0
	eq.MidGain = 0
	eq.Parent = wind
	
	-- Body Sound
	body = parent:FindFirstChild("BodySound") or Instance.new("Sound")
	body.Name = "BodySound"
	body.RollOffMaxDistance = 100
	body.RollOffMinDistance = 10
	body.RollOffMode = Enum.RollOffMode.InverseTapered
	body.Looped = true
	body.SoundId = "rbxassetid://4471836491"
	body.Volume = 0
	body.Parent = parent
	
	return wind, body
end

-- Starts playing all sounds
function Sounds.Play()
	if wind then wind:Play() end
	if body then body:Play() end
end

-- Updates sound volumes based on velocity magnitude
function Sounds.Update(velocityMagnitude)
	local windVol = velocityMagnitude^2 * Sounds.Config.WindVolume / (200)^2
	local bodyVol = velocityMagnitude^2 * Sounds.Config.BodyVolume / (200)^2
	
	if wind then wind.Volume = windVol end
	if body then body.Volume = bodyVol end
end

-- Cleans up all sounds
function Sounds.Destroy()
	if wind then wind:Destroy() wind = nil end
	if body then body:Destroy() body = nil end
	eq = nil
end

return Sounds