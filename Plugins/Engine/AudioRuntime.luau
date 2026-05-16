-- Engine Sounds Runtime Module - Duplicated from Sounds plugin

local RunService = game:GetService("RunService")

local AudioRuntime = {}
AudioRuntime.__index = AudioRuntime

function AudioRuntime.new(car, values, event, DIRECTORY)
	local self = setmetatable({}, AudioRuntime)
	
	self.Car = car
	self.Values = values
	self.Event = event
	self.DIRECTORY = DIRECTORY
	self.FE = false
	self.FE_RATE = 1/15
	
	self.sounds = {}
	self.vvl = 0
	self.soundEQCache = {}
	self.modifierDataCache = {}
	self.rpm = 0
	self.AverageRotSpeed = 0
	self.rpmHistory = {}
	
	self.RPMValue = values.RPM
	self.ThrottleValue = values.Throttle
	self.ClutchValue = values.Clutch
	self.GearValue = values.Gear
	self.BoostTurboValue = values.BoostTurbo
	self.BoostSuperValue = values.BoostSuper
	self.StartingValue = car.Parent.IsOn.Starting
	self.IsOnValue = car.Parent.IsOn
	
	self._Tune = require(car["A-Chassis Tune"])
	self.Units = require(car["A-Chassis Tune"].README.Units)
	
	self:InitializeSounds()
	
	return self
end

function AudioRuntime:cacheEQData(eq)
	if eq == nil then return end
	self.modifierDataCache[eq] = {
		LowGain = eq.LowGain,
		MidGain = eq.MidGain,
		HighGain = eq.HighGain,
	}
end

function AudioRuntime:cacheDistortionData(dist)
	if dist == nil then return end
	self.modifierDataCache[dist] = dist.Level
end

function AudioRuntime:InitializeSounds()
	for _, sound in self.Car.Parent:GetChildren() do
		if not sound:IsA("Sound") then continue end
		
		local soundParent = self.DIRECTORY:FindFirstChild(sound:GetAttribute("SoundParent")) or self.Car.Body["#Weight"]
		local newSound = soundParent:FindFirstChild(sound.Name.."_Local")
		
		if newSound then
			newSound:Destroy()
		end
		
		newSound = sound:Clone()
		
		local offEQ = sound:FindFirstChild("OffEQ") or sound:FindFirstChild("ThrottleEQ") or sound:FindFirstChild("VVLEQ")
		local throttleEQ = sound:FindFirstChild("ThrottleEQ") or sound:FindFirstChild("OffEQ") or sound:FindFirstChild("VVLEQ")
		local vvlEQ = sound:FindFirstChild("VVLEQ") or sound:FindFirstChild("ThrottleEQ") or sound:FindFirstChild("OffEQ")
		local offDist = sound:FindFirstChild("OffDistortion") or sound:FindFirstChild("ThrottleDistortion")
		local throttleDist = sound:FindFirstChild("ThrottleDistortion") or sound:FindFirstChild("OffDistortion")
		
		self.soundEQCache[newSound] = {offEQ, throttleEQ, vvlEQ, offDist, throttleDist}
		
		self:cacheEQData(offEQ)
		self:cacheEQData(throttleEQ)
		self:cacheEQData(vvlEQ)
		self:cacheDistortionData(offDist)
		self:cacheDistortionData(throttleDist)
		
		newSound.Volume = 0
		newSound.Playing = false
		newSound.Parent = self.DIRECTORY and self.DIRECTORY:FindFirstChild(newSound:GetAttribute("SoundParent")) or self.Car.Body["#Weight"]
		
		local eq = Instance.new("EqualizerSoundEffect", newSound)
		eq.Name = "#EQ"
		eq.LowGain = 0
		eq.MidGain = 0
		eq.HighGain = 0
		
		local dist = Instance.new("DistortionSoundEffect", newSound)
		dist.Name = "#Distortion"
		dist.Level = 0
		
		local soundData = {
			Sound = newSound,
			EQ = eq,
			Distortion = dist,
			type = string.sub(sound.Name, 1, 3),
			Playing = false,
			BaseVolume = sound:GetAttribute("BaseVolume"),
			RedlineVolume = sound:GetAttribute("RedlineVolume"),
			RedlinePlaybackSpeed = sound:GetAttribute("RedlinePlaybackSpeed"),
			RangeStart = sound:GetAttribute("RangeStart"),
			RangeEnd = sound:GetAttribute("RangeEnd"),
			ThrottleVolume = sound:GetAttribute("ThrottleVolume"),
			TransitionStart = sound:GetAttribute("TransitionStart"),
			TransitionEnd = sound:GetAttribute("TransitionEnd"),
			ClutchVolume = sound:GetAttribute("ClutchVolume"),
			OffVolume = sound:GetAttribute("OffVolume"),
			VariableVolume = sound:GetAttribute("VariableVolume"),
			VolumeIncrease = sound:GetAttribute("VolumeIncrease"),
			PlaybackSpeedIncrease = sound:GetAttribute("PlaybackSpeedIncrease"),
			VariablePlaybackSpeed = sound:GetAttribute("VariablePlaybackSpeed"),
			BasePlaybackSpeed = sound:GetAttribute("BasePlaybackSpeed"),
			MaxPitch = sound:GetAttribute("MaxPitch"),
			Sensitivity = sound:GetAttribute("Sensitivity"),
			Gears = string.split(string.gsub(sound:GetAttribute("Gears") or "", " ", ""), ","),
			Pitch = sound:GetAttribute("Pitch"),
		}
		
		table.insert(self.sounds, soundData)
	end
end

function AudioRuntime:f(m, n, p, q, M, b, x)
	return (m * x + n) / (p * x + q) + M * math.sin(b * x)
end

function AudioRuntime:eqGain(sound, gainType, throt)
	local eqData = self.soundEQCache[sound]
	if not eqData then return 0 end
	
	local eq
	if gainType == "off" then
		eq = eqData[1]
	elseif gainType == "throttle" then
		eq = eqData[2]
	elseif gainType == "vvl" then
		eq = eqData[3]
	end
	
	if not eq then return 0 end
	
	local data = self.modifierDataCache[eq]
	if not data then return 0 end
	
	local low = data.LowGain or 0
	local mid = data.MidGain or 0
	local high = data.HighGain or 0
	
	return low + (mid - low) * throt, mid + (high - mid) * throt
end

function AudioRuntime:distGain(sound, throt)
	local eqData = self.soundEQCache[sound]
	if not eqData then return 0 end
	
	local offDist = eqData[4]
	local throttleDist = eqData[5]
	
	local offLevel = offDist and self.modifierDataCache[offDist] or 0
	local throttleLevel = throttleDist and self.modifierDataCache[throttleDist] or 0
	
	return offLevel + (throttleLevel - offLevel) * throt
end

function AudioRuntime:RuntimeLoop(dt)
	local isOn = self.IsOnValue.Value
	local starting = self.StartingValue.Value
	local rpm = self.RPMValue.Value
	local throttle = self.ThrottleValue.Value
	local clutch = self.ClutchValue.Value
	local gear = self.GearValue.Value
	local boostTurbo = self.BoostTurboValue.Value
	local boostSuper = self.BoostSuperValue.Value
	
	local tune = self._Tune
	local idleRPM = tune.IdleRPM or 0
	local redlineRPM = tune.Redline or 1
	
	local rpmNorm = (rpm - idleRPM) / math.max(1, (redlineRPM - idleRPM))
	rpmNorm = math.clamp(rpmNorm, 0, 1)
	
	local base = 0
	local redline = 0
	
	for _, soundData in self.sounds do
		local sound = soundData.Sound
		if soundData.type == "ENG" then
			base = soundData.BasePlaybackSpeed or 1
			redline = soundData.RedlinePlaybackSpeed or 1
			local newSpeed = base + (redline - base) * rpmNorm
			sound.PlaybackSpeed = newSpeed
			-- Volume logic for engine sound
			local baseVol = soundData.BaseVolume or 0
			local throttleVol = soundData.ThrottleVolume or 0
			local redlineVol = soundData.RedlineVolume or 0
			local tStart = soundData.TransitionStart or 1
			local tEnd = soundData.TransitionEnd or 1
			local rStart = soundData.RangeStart or 0
			local rEnd = soundData.RangeEnd or 0
			sound.Volume = isOn
				and (baseVol + (throttleVol * throttle) + (redlineVol * (rpm / (tune.Redline or 1))))
				* math.clamp(1 / tStart * (rpm - rStart), 0, 1)
				* math.clamp(-1 / tEnd * (rpm - rEnd), 0, 1)
				or 0
			if not soundData.Playing then
				sound.Playing = true
				soundData.Playing = true
			end
		elseif soundData.type == "TRA" then
			-- Transmission sound: needs speedFactor
			local speedFactor = 1 -- TODO: Replace with actual calculation if needed
			sound.Volume = isOn and (soundData.BaseVolume or 0) * speedFactor or 0
			sound.PlaybackSpeed = (soundData.VariablePlaybackSpeed or 1) * speedFactor
			if not soundData.Playing then
				sound.Playing = true
				soundData.Playing = true
			end
		elseif soundData.type == "TUR" then
			local speedFactor = 1 -- TODO: Replace with actual calculation if needed
			sound.Volume = isOn and (soundData.VolumeIncrease or 0) * boostTurbo or 0
			sound.PlaybackSpeed = (soundData.VariablePlaybackSpeed or 1) * speedFactor
			if not soundData.Playing then
				sound.Playing = true
				soundData.Playing = true
			end
		elseif soundData.type == "SUP" then
			local speedFactor = 1 -- TODO: Replace with actual calculation if needed
			sound.Volume = isOn and (soundData.VolumeIncrease or 0) * boostSuper or 0
			sound.PlaybackSpeed = (soundData.VariablePlaybackSpeed or 1) * speedFactor
			if not soundData.Playing then
				sound.Playing = true
				soundData.Playing = true
			end
		elseif soundData.type == "BOV" then
			if not soundData.Playing and throttle < 0.5 and boostTurbo > 0.5 then
				sound:Play()
				soundData.Playing = true
				self.updateBOV = true
			end
		elseif soundData.type == "IGN" then
			if sound.Name == "IGN_Starter" then
				if starting and not soundData.Playing then
					sound:Play()
					soundData.Playing = true
				elseif not starting and soundData.Playing then
					sound:Stop()
					soundData.Playing = false
				end
			elseif sound.Name == "IGN_Ignition" then
				sound.Volume = isOn and (soundData.Volume or sound.Sound.Volume) or 0
				if not soundData.Playing then
					sound.Playing = true
					soundData.Playing = true
				end
			end
		end
	end
	if self.updateBOV then
		self.updateBOV = false
	end
end

function AudioRuntime:FELoop()
	if not self.FE then return end
	
	local packet = buffer.create(17)
	
	buffer.writef32(packet, 0, self.RPMValue.Value)
	buffer.writef32(packet, 4, self.ThrottleValue.Value)
	buffer.writef32(packet, 8, self.ClutchValue.Value)
	buffer.writef32(packet, 12, self.GearValue.Value)
	buffer.writeu8(packet, 16, self.IsOnValue.Value and 1 or 0)
	
	self.Event:FireServer(packet)
end

function AudioRuntime:Start()
	self.Car.DriveSeat.ChildAdded:Connect(function(child)
		if child:IsA("Humanoid") then
			RunService.RenderStepped:Connect(function(dt)
				self:RuntimeLoop(dt)
			end)
			if self.FE then
				task.spawn(function()
					while task.wait(self.FE_RATE) do
						self:FELoop()
					end
				end)
			end
		end
	end)
	
	self.Car.DriveSeat.ChildRemoved:Connect(function(child)
		if child:IsA("Humanoid") then
			for _, soundData in self.sounds do
				soundData.Sound:Stop()
				soundData.Sound.Volume = 0
			end
		end
	end)
end

return function(...)
	return AudioRuntime.new(...)
end
