-- Engine Sounds Runtime Module
-- Mirrors the A-Chassis Sounds plugin logic for engine audio playback.
-- The Engine plugin owns this runtime; the Sounds plugin stays disabled.

local RunService = game:GetService("RunService")

local AudioRuntime = {}
AudioRuntime.__index = AudioRuntime

function AudioRuntime.new(car, values, event, DIRECTORY, soundsContainer, isOnValue)
	local self = setmetatable({}, AudioRuntime)

	self.Car = car
	self.Values = values
	self.Event = event
	self.DIRECTORY = DIRECTORY
	self.soundsContainer = soundsContainer
	self.FE = false
	self.FE_RATE = 1/15

	self.sounds = {}
	self.vvl = 0
	self.soundEQCache = {}
	self.modifierDataCache = {}
	self.rpm = 0
	self.AverageRotSpeed = 0
	self.rpmHistory = {}

	self.RPMValue = values:FindFirstChild("RPM")
	self.ThrottleValue = values:FindFirstChild("Throttle")
	self.ClutchValue = values:FindFirstChild("Clutch")
	self.GearValue = values:FindFirstChild("Gear")
	self.BoostTurboValue = values:FindFirstChild("BoostTurbo")
	self.BoostSuperValue = values:FindFirstChild("BoostSuper")
	self.StartingValue = isOnValue and isOnValue:FindFirstChild("Starting")
	self.IsOnValue = isOnValue

	self._Tune = require(car["A-Chassis Tune"])
	self.Units = require(car["A-Chassis Tune"].README.Units)

	self.updateBOV = false
	self.lastBOV = tick()
	self.last = tick()
	self.prevBoost = 0
	self.noCustomEngine = car["A-Chassis Tune"].README:FindFirstChild("CustomEngine") == nil
	self.WheelSpeedsChildren = values:FindFirstChild("WheelSpeeds")
		and values.WheelSpeeds:GetChildren() or {}

	self:InitializeSounds()

	return self
end

function AudioRuntime:cacheEQData(eq)
	if eq == nil then return end
	self.modifierDataCache[eq] = {
		HighGain = eq.HighGain,
		LowGain = eq.LowGain,
		MidGain = eq.MidGain,
	}
end

function AudioRuntime:cacheDistortionData(dist)
	if dist == nil then return end
	self.modifierDataCache[dist] = dist.Level
end

function AudioRuntime:InitializeSounds()
	local container = self.soundsContainer
	if not container then return end

	for _, sound in container:GetChildren() do
		if not sound:IsA("Sound") then continue end

		local soundParent = self.DIRECTORY
			and self.DIRECTORY:FindFirstChild(sound:GetAttribute("SoundParent"))
			or self.Car.Body:FindFirstChild("#Weight")
		local newSound = soundParent and soundParent:FindFirstChild(sound.Name.."_Local")

		local soundData = {}
		if not newSound then
			newSound = sound:Clone()
			newSound.Name = newSound.Name.."_Local"

			newSound.Playing = false
			newSound.Volume = 0
			newSound.Parent = soundParent

			-- Create runtime EQ and Distortion effects on the cloned sound
			local eq = Instance.new("EqualizerSoundEffect", newSound)
			eq.Name = "#EQ"
			eq.HighGain = 0
			eq.MidGain = 0
			eq.LowGain = 0
			local dist = Instance.new("DistortionSoundEffect", newSound)
			dist.Name = "#Distortion"
			dist.Level = 0

			soundData.EQ = eq
			soundData.Distortion = dist
		end

		-- FE server sound replication
		if self.FE and soundParent then
			local serverSound = soundParent:FindFirstChild(sound.Name)
			if serverSound then
				serverSound:SetAttribute("SoundId", serverSound.SoundId)
				serverSound.SoundId = ""
				soundData.ServerSound = serverSound
			end
		end

		-- Cache EQ/Distortion modifier data from the ORIGINAL sound template
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

		-- Disable original EQ/Distortion effects on the cloned sound
		if newSound:FindFirstChild("OffDistortion") then newSound.OffDistortion.Enabled = false end
		if newSound:FindFirstChild("OffEQ") then newSound.OffEQ.Enabled = false end
		if newSound:FindFirstChild("ThrottleDistortion") then newSound.ThrottleDistortion.Enabled = false end
		if newSound:FindFirstChild("ThrottleEQ") then newSound.ThrottleEQ.Enabled = false end
		if newSound:FindFirstChild("VVLEQ") then newSound.VVLEQ.Enabled = false end

		soundData.Sound = newSound
		soundData.Playing = false
		soundData.type = string.sub(sound.Name, 1, 3)
		soundData.EQ = newSound:FindFirstChild("#EQ")
		soundData.Distortion = newSound:FindFirstChild("#Distortion")

		-- Cache all sound attributes from the original template
		soundData.BasePlaybackSpeed = sound:GetAttribute("BasePlaybackSpeed")
		soundData.BaseVolume = sound:GetAttribute("BaseVolume")
		soundData.RangeEnd = sound:GetAttribute("RangeEnd")
		soundData.RangeStart = sound:GetAttribute("RangeStart")
		soundData.RedlinePlaybackSpeed = sound:GetAttribute("RedlinePlaybackSpeed")
		soundData.RedlineVolume = sound:GetAttribute("RedlineVolume")
		soundData.ThrottleVolume = sound:GetAttribute("ThrottleVolume")
		soundData.TransitionEnd = sound:GetAttribute("TransitionEnd")
		soundData.TransitionStart = sound:GetAttribute("TransitionStart")
		soundData.ClutchVolume = sound:GetAttribute("ClutchVolume")
		soundData.Gears = string.split(string.gsub(soundData.Sound:GetAttribute("Gears") or "", " ", ""), ",")
		soundData.OffVolume = sound:GetAttribute("OffVolume")
		soundData.VariablePlaybackSpeed = sound:GetAttribute("VariablePlaybackSpeed")
		soundData.VariableVolume = sound:GetAttribute("VariableVolume")
		soundData.PlaybackSpeedIncrease = sound:GetAttribute("PlaybackSpeedIncrease")
		soundData.VolumeIncrease = sound:GetAttribute("VolumeIncrease")
		soundData.Sensitivity = sound:GetAttribute("Sensitivity")
		soundData.MaxPitch = sound:GetAttribute("MaxPitch")
		soundData.Pitch = sound:GetAttribute("Pitch")
		soundData.Volume = sound:GetAttribute("Volume")

		table.insert(self.sounds, soundData)
	end
end

-- VVL calculation (mirrors Sounds plugin)
function AudioRuntime:f(m, n, p, q, M, b, x)
	return math.clamp(M - ((q - n) / (b^p - b^m) * (b^x - b^m) + n), 0, M)
end

-- EQ gain interpolation (mirrors Sounds plugin)
function AudioRuntime:eqGain(sound, gainType, throt)
	local cache = self.soundEQCache[sound]
	if not cache then return 0 end
	local offEQ = cache[1]
	if not offEQ then return 0 end
	local throttleEQ = cache[2]
	local vvlEQ = cache[3]
	local data = self.modifierDataCache[offEQ]
	if not data then return 0 end
	return data[gainType]
		+ ((self.modifierDataCache[throttleEQ][gainType]
			+ (self.modifierDataCache[vvlEQ][gainType]
				- self.modifierDataCache[throttleEQ][gainType]) * self.vvl)
			- data[gainType]) * throt
end

-- Distortion gain interpolation (mirrors Sounds plugin)
function AudioRuntime:distGain(sound, throt)
	local cache = self.soundEQCache[sound]
	if not cache then return 0 end
	local offDist = cache[4]
	if not offDist then return 0 end
	local throttleDist = cache[5]
	return self.modifierDataCache[offDist]
		+ (self.modifierDataCache[throttleDist] - self.modifierDataCache[offDist]) * throt
end

function AudioRuntime:RuntimeLoop(dt)
	-- Throttle to ~60fps (mirrors Sounds plugin)
	if tick() - self.last < 1/60 then return end
	self.last = tick()

	-- Calculate smooth RPM (8-sample rolling average)
	table.insert(self.rpmHistory, self.RPMValue.Value)
	if #self.rpmHistory > 8 then
		table.remove(self.rpmHistory, 1)
	end
	self.rpm = 0
	for _, v in self.rpmHistory do
		self.rpm = self.rpm + v
	end
	self.rpm = self.rpm / #self.rpmHistory

	-- Calculate VVL (variable valve lift)
	if self._Tune.CustomEngineCalculations == false or self.noCustomEngine then
		if self._Tune.VVLTorque > 0 then
			self.vvl = (self._Tune.VVLTorque
				- self:f(
					self._Tune.VVLRPM / 1000, 0,
					(self._Tune.VVLRPM + self._Tune.VVLTime) / 1000,
					self._Tune.VVLTorque,
					self._Tune.VVLTorque,
					self._Tune.VVLCurve,
					self.rpm / 1000
				)) / self._Tune.VVLTorque
		else
			self.vvl = 0
		end
	end

	-- Transmission rotation speed from wheel speeds
	self.AverageRotSpeed = 0
	local count = 0
	for _, wheel in self.WheelSpeedsChildren do
		if string.find(wheel.Name, "F") then
			if not (self._Tune.Config == "FWD" or self._Tune.Config == "AWD") then continue end
			self.AverageRotSpeed += wheel.Value
			count += 1
		else
			if not (self._Tune.Config == "RWD" or self._Tune.Config == "AWD") then continue end
			self.AverageRotSpeed += wheel.Value
			count += 1
		end
	end
	if count > 0 then
		self.AverageRotSpeed /= count
	end

	local IsOn = self.IsOnValue and self.IsOnValue.Value and 1 or 0
	local ThrottleVal = self.ThrottleValue.Value
	local ClutchVal = self.ClutchValue.Value
	local GearVal = self.GearValue.Value
	local BoostTurboVal = self.BoostTurboValue.Value
	local BoostSuperVal = self.BoostSuperValue.Value
	local StartingVal = self.StartingValue and self.StartingValue.Value or false

	for _, soundData in self.sounds do
		if soundData.type == "ENG" then
			if soundData.Playing == false then
				soundData.Playing = true
				soundData.Sound.Playing = true
			end
			soundData.EQ.HighGain = self:eqGain(soundData.Sound, "HighGain", ThrottleVal)
			soundData.EQ.MidGain = self:eqGain(soundData.Sound, "MidGain", ThrottleVal)
			soundData.EQ.LowGain = self:eqGain(soundData.Sound, "LowGain", ThrottleVal)
			soundData.Distortion.Level = self:distGain(soundData.Sound, ThrottleVal)
			soundData.Sound.PlaybackSpeed = soundData.BasePlaybackSpeed
			+ (soundData.RedlinePlaybackSpeed - soundData.BasePlaybackSpeed)
				* (self.rpm / self._Tune.Redline)
			soundData.Sound.Volume = IsOn
				* (soundData.BaseVolume
					+ (soundData.ThrottleVolume * ThrottleVal)
					+ (soundData.RedlineVolume * (self.rpm / self._Tune.Redline)))
				* math.clamp(1 / soundData.TransitionStart * (self.rpm - soundData.RangeStart), 0, 1)
				* math.clamp(-1 / soundData.TransitionEnd * (self.rpm - soundData.RangeEnd), 0, 1)

		elseif soundData.type == "TRA" then
			if soundData.Playing == false then
				soundData.Playing = true
				soundData.Sound.Playing = true
			end
			soundData.Sound.PlaybackSpeed = soundData.VariablePlaybackSpeed
				* (self.AverageRotSpeed / (300 * (self.Units.Length_mm / 1000) * 3.6))
			soundData.Sound.Volume = table.find(soundData.Gears, tostring(GearVal))
				and (soundData.ClutchVolume
					+ ((soundData.BaseVolume
						+ soundData.VariableVolume
							* (self.AverageRotSpeed / (300 * (self.Units.Length_mm / 1000) * 3.6)))
					- soundData.ClutchVolume) * (1 - ClutchVal)
					+ soundData.ThrottleVolume * ThrottleVal)
				or soundData.OffVolume

		elseif soundData.type == "TUR" then
			if soundData.Playing == false then
				soundData.Playing = true
				soundData.Sound.Playing = true
			end
			soundData.Sound.PlaybackSpeed = soundData.BasePlaybackSpeed
			+ soundData.PlaybackSpeedIncrease * BoostTurboVal
			soundData.Sound.Volume = soundData.VolumeIncrease * BoostTurboVal

		elseif soundData.type == "SUP" then
			if soundData.Playing == false then
				soundData.Playing = true
				soundData.Sound.Playing = true
			end
			soundData.Sound.PlaybackSpeed = soundData.BasePlaybackSpeed
			+ soundData.PlaybackSpeedIncrease * BoostSuperVal
			soundData.Sound.Volume = soundData.VolumeIncrease * BoostSuperVal

		elseif soundData.type == "BOV" then
			if (BoostTurboVal - soundData.Sensitivity < self.prevBoost)
				and (tick() - self.lastBOV > 1)
				and ThrottleVal < 0.8 then
				self.updateBOV = true
				soundData.Sound.PlaybackSpeed = soundData.BasePlaybackSpeed
				+ soundData.PlaybackSpeedIncrease * BoostTurboVal
				soundData.Sound.Volume = soundData.VolumeIncrease * BoostTurboVal
				soundData.Sound.TimePosition = 0
				soundData.Sound.Playing = true
			end
			self.prevBoost = BoostTurboVal

		elseif soundData.type == "IGN" then
			if StartingVal then
				if not soundData.Sound:GetAttribute("Played") then
					soundData.Sound.TimePosition = 0
					soundData.Sound.Playing = true
					soundData.Playing = true
				end
				soundData.Sound:SetAttribute("Played", true)
				soundData.Sound.Volume = soundData.Volume
				soundData.Sound.PlaybackSpeed = soundData.Pitch
				+ (soundData.MaxPitch - soundData.Pitch)
					* (self.rpm / self._Tune.IgnitionRPM)
			else
				soundData.Sound:SetAttribute("Played", false)
				if soundData.Playing == true then
					soundData.Playing = false
					soundData.Sound.Playing = false
				end
			end
		end
	end

	if self.updateBOV then
		self.lastBOV = tick()
		self.updateBOV = false
	end
end

function AudioRuntime:FELoop()
	if not self.FE then return end

	local packet = buffer.create(17)
	buffer.writeu16(packet, 0, math.clamp(math.round(self.rpm), 0, 65535))
	buffer.writeu8(packet, 2, math.clamp(math.round(self.ThrottleValue.Value * 255), 0, 255))
	buffer.writeu16(packet, 3, math.clamp(math.round(self.AverageRotSpeed), 0, 65535))
	buffer.writei8(packet, 5, self.GearValue.Value)
	buffer.writeu8(packet, 6, math.clamp(math.round(self.ClutchValue.Value * 255), 0, 255))
	buffer.writef32(packet, 7, math.round(self.BoostTurboValue.Value * 100) / 100)
	buffer.writef32(packet, 11, math.round(self.BoostSuperValue.Value * 100) / 100)
	buffer.writeu8(packet, 15, self.StartingValue and self.StartingValue.Value and 1 or 0)
	buffer.writeu8(packet, 16, self.IsOnValue and self.IsOnValue.Value and 1 or 0)
	self.Event:FireServer(packet)
end

function AudioRuntime:Start()
	-- Run the audio loop on Heartbeat (mirrors Sounds plugin)
	RunService.Heartbeat:Connect(function(dt)
		self:RuntimeLoop(dt)
	end)

	-- FE loop for server sound replication
	if self.FE then
		task.spawn(function()
			while task.wait(self.FE_RATE) do
				self:FELoop()
			end
		end)
	end

	-- Cleanup when the driver leaves the seat
	self.Car.DriveSeat.ChildRemoved:Connect(function(child)
		if child:IsA("Weld") and child.Name == "SeatWeld" then
			for _, soundData in self.sounds do
				soundData.Sound.Playing = false
				if soundData.ServerSound then
					soundData.ServerSound.Playing = false
					soundData.ServerSound.SoundId = soundData.ServerSound:GetAttribute("SoundId")
				end
			end
		end
	end)
end

return function(...)
	return AudioRuntime.new(...)
end
