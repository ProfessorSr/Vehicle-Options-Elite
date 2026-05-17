 
-- V O E   P L U G I N S • Engine
-- DATE (UTC):
--
-- DESCRIPTION:
-- Plugin entry point.
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)

-- - Clean, modular, no deprecated code
--====================================================================
-- Module Requires
--====================================================================
local EngineConfig = require(script:WaitForChild("Config"))
local EngineTags = require(script:WaitForChild("Tags"))
-- (Sound and AudioRuntime modules removed)
local PartAccess = require(script:WaitForChild("PartAccess"))
if EngineConfig and EngineConfig.Enabled == false then
	warn("[Engine] Plugin disabled via config")
	return
end
--====================================================================
-- Services
--====================================================================
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
--====================================================================
-- Context Resolution
--====================================================================
local function findRuntimeCarAndValues()
	local pluginContainer = script.Parent
	local carValue = pluginContainer:FindFirstChild("Car")
	local valuesFolder = pluginContainer:FindFirstChild("Values")

	if carValue and carValue:IsA("ObjectValue") and carValue.Value and carValue.Value:IsA("Model") then
		local vehicle = carValue.Value
		-- First, check for VOE_State folder (preferred)
		local voeState = vehicle:FindFirstChild("VOE_State")
		if voeState then
			return vehicle, voeState
		end
		-- Fallback to Values folder (legacy)
		return vehicle, valuesFolder
	end
	return nil, valuesFolder
end
--====================================================================
-- Configuration
--====================================================================
local Engine = {}
Engine.__index = Engine
--====================================================================
-- Helper Functions

--====================================================================
local function findTuneModule(vehicleModel)
	if not vehicleModel then return nil end
	local candidates = {"Tune", "VehicleTune", "Vehicle Tune"}
	for _, name in ipairs(candidates) do
		local mod = vehicleModel:FindFirstChild(name) or vehicleModel:FindFirstChild(name, true)
		if mod and mod:IsA("ModuleScript") then
			return mod
		end
	end
	return nil
end
local function debugLog(category, message)
	print(string.format("[Engine][%s] %s", category, message))
end
local function axisVector(axisName, defaultAxis)
	local axis = string.upper(tostring(axisName or defaultAxis or "X"))
	if axis == "Y" then
		return Vector3.new(0, 1, 0)
	elseif axis == "Z" then
		return Vector3.new(0, 0, 1)
	end
	return Vector3.new(1, 0, 0)
end
local function ensureWeldedToRoot(rootPart, parts, weldName)
	for _, part in ipairs(parts) do
		if part ~= rootPart then
			local already = false
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("WeldConstraint") and (child.Part0 == rootPart or child.Part1 == rootPart) then
					already = true
					break
				end
			end
			if not already then
				local weld = Instance.new("WeldConstraint")
				weld.Name = weldName
				weld.Part0 = rootPart
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
end
function Engine.getPluginInfo()
	return {
		Name = EngineTags.Name,
		Actions = {"SetRPMHint"},
		StateValues = {
			Running = {ClassName = "BoolValue", Default = false, VOE_Owner = "Engine", VOE_Type = "State"},
			EngineRPM = {ClassName = "NumberValue", Default = 0, VOE_Owner = "Engine", VOE_Type = "State"},
			EngineRPMMaxOverride = {ClassName = "NumberValue", Default = 0, VOE_Owner = "Engine", VOE_Type = "State"},
			EngineTemp = {
				ClassName = "NumberValue",
				Default = tonumber(EngineConfig.EngineTemp and EngineConfig.EngineTemp.Ambient) or 80,
				VOE_Owner = "Engine", VOE_Type = "State"
			},
			EngineWear = {
				ClassName = "NumberValue",
				Default = tonumber(EngineConfig.EngineWear and EngineConfig.EngineWear.StartingValue) or 100,
				VOE_Owner = "Engine", VOE_Type = "State"
			},
			BatteryPercent = {
				ClassName = "NumberValue",
				Default = tonumber(EngineConfig.BatterySystem and EngineConfig.BatterySystem.StartingPercent) or 100,
				VOE_Owner = "Engine", VOE_Type = "State"
			},
			BatteryVoltage = {
				ClassName = "NumberValue",
				Default = tonumber(EngineConfig.BatterySystem and EngineConfig.BatterySystem.MaxVoltage) or 12.6,
				VOE_Owner = "Engine", VOE_Type = "State"
			},
			BatteryLow = {ClassName = "BoolValue", Default = false, VOE_Owner = "Engine", VOE_Type = "State"},
			AlternatorOn = {ClassName = "BoolValue", Default = false, VOE_Owner = "Engine", VOE_Type = "State"},
			CoolantLevel = {
				ClassName = "NumberValue",
				Default = tonumber(EngineConfig.CoolantSystem and EngineConfig.CoolantSystem.StartingLevel) or 100,
				VOE_Owner = "Engine", VOE_Type = "State"
			},
			CoolantPressure = {
				ClassName = "NumberValue",
				Default = tonumber(EngineConfig.CoolantSystem and EngineConfig.CoolantSystem.PressureAtIdle) or 10,
				VOE_Owner = "Engine", VOE_Type = "State"
			},
			CoolantWarning = {ClassName = "BoolValue", Default = false, VOE_Owner = "Engine", VOE_Type = "State"},
			EngineLimpMode = {ClassName = "BoolValue", Default = false, VOE_Owner = "Engine", VOE_Type = "State"},
			CheckEngine = {ClassName = "BoolValue", Default = false, VOE_Owner = "Engine", VOE_Type = "State"},
			MaintenanceMilesRemaining = {
				ClassName = "NumberValue",
				Default = tonumber(EngineConfig.Maintenance and EngineConfig.Maintenance.StartingMilesRemaining) or 5000,
				VOE_Owner = "Engine", VOE_Type = "State"
			},
			MaintenanceDue = {ClassName = "BoolValue", Default = false, VOE_Owner = "Engine", VOE_Type = "State"},
			OilPressure = {
				ClassName = "NumberValue",
				Default = tonumber(EngineConfig.OilPressure and EngineConfig.OilPressure.PressureAtIdle) or 24,
				VOE_Owner = "Engine", VOE_Type = "State"
			},
			OilPressureWarning = {ClassName = "BoolValue", Default = false, VOE_Owner = "Engine", VOE_Type = "State"},
		},
		
	}
end
function Engine.create(context)
	local partAccess = PartAccess.new(context.CollectionService, context.VehicleModel)
	local inst = setmetatable({
		State = context.State,
		GlobalConfig = context.Config,
		VehicleModel = context.VehicleModel,
		Seat = context.Seat,
		TaggedInstances = function(tagName)
			return partAccess:taggedInstances(tagName)
		end,
		ResolveBasePart = function(inst)
			return PartAccess.resolveBasePart(inst)
		end,
		ResolveRootPart = function(inst)
			return PartAccess.resolveRootPart(inst)
		end,
		RPMHintValue = nil,
		RPMHintStamp = 0,
		ResolvedIdleRPM = nil,
		ResolvedMaxRPM = nil,
		EngineWearAccumulator = 0,
		MaintenanceAccumulator = 0,
		_lastTotalDamage = 0,
		_engineFailed = false,
		_misfireRemaining = 0,
	}, Engine)

	-- Attribute persistence: read any existing attributes on the vehicle and
	-- keep attributes updated when important state values change. Attributes
	-- are authoritative on the server and safe for client read-only visibility.
	local function tryReadNumber(model, name)
		if not model then return nil end
		local v = model:GetAttribute(name)
		if v == nil then return nil end
		return tonumber(v)
	end
	local function tryReadBool(model, name)
		if not model then return nil end
		local v = model:GetAttribute(name)
		if v == nil then return nil end
		return v == true
	end

	if inst.VehicleModel and inst.State then
		local syncList = {
			{attr = "EngineWear", state = "EngineWear", kind = "number"},
			{attr = "MaintenanceMilesRemaining", state = "MaintenanceMilesRemaining", kind = "number"},
			{attr = "CoolantLevel", state = "CoolantLevel", kind = "number"},
			{attr = "EngineTemp", state = "EngineTemp", kind = "number"},
			{attr = "OilPressure", state = "OilPressure", kind = "number"},
			{attr = "CheckEngine", state = "CheckEngine", kind = "bool"},
		}

		for _, spec in ipairs(syncList) do
			local s = inst.State[spec.state]
			if s and s.Parent then
				-- read attribute if present
				if spec.kind == "number" then
					local n = tryReadNumber(inst.VehicleModel, spec.attr)
					if n ~= nil then
						pcall(function() s.Value = n end)
					end
				else
					local b = tryReadBool(inst.VehicleModel, spec.attr)
					if b ~= nil then
						pcall(function() s.Value = b end)
					end
				end

				-- write back on change
				s.Changed:Connect(function()
					if not inst.VehicleModel then return end
					local v = s.Value
					if spec.kind == "number" then
						inst.VehicleModel:SetAttribute(spec.attr, tonumber(v) or 0)
					else
						inst.VehicleModel:SetAttribute(spec.attr, v == true)
					end
				end)
			end
		end
	end

	return inst
end
local TUNE_VALUE_ALIASES = {
	IdleRPM = { "IdleRPM", "IdleRpm", "Idle", "IdleSpeed", "EngineIdleRPM" },
	Redline = { "Redline", "RedLine", "MaxRPM", "MaxRpm", "RevLimit", "Limiter" },
}
function Engine:resolveTuneValue(fieldName, fallback)
	if not self._acTune then
		local tuneModule = findTuneModule(self.VehicleModel)
		if tuneModule and tuneModule:IsA("ModuleScript") then
			local ok, data = pcall(require, tuneModule)
			self._acTune = (ok and type(data) == "table") and data or {}
		else
			self._acTune = {}
		end
	end
	local aliases = TUNE_VALUE_ALIASES[fieldName] or { fieldName }
	for _, key in ipairs(aliases) do
		local value = tonumber(self._acTune[key])
		if value and value > 0 then
			return value
		end
	end
	return tonumber(fallback) or 0
end
function Engine:resolveIdleRPM()
	if not self.ResolvedIdleRPM then
		self.ResolvedIdleRPM = self:resolveTuneValue("IdleRPM", EngineConfig.EngineState and EngineConfig.EngineState.IdleRPM or 800)
	end
	return self.ResolvedIdleRPM
end
function Engine:resolveMaxRPM()
	if not self.ResolvedMaxRPM then
		self.ResolvedMaxRPM = self:resolveTuneValue("Redline", EngineConfig.EngineState and EngineConfig.EngineState.MaxRPM or 7000)
	end
	return self.ResolvedMaxRPM
end
function Engine:collectTaggedParts(tagName, resolveFn)
	local out = {}
	if typeof(tagName) ~= "string" or tagName == "" then
		return out
	end
	for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
		local part = resolveFn(inst)
		if part and part ~= self.Seat then
			table.insert(out, part)
		end
	end
	return out
end
function Engine:setup()
	local ambientTemp = tonumber(EngineConfig.EngineTemp and EngineConfig.EngineTemp.Ambient) or 80
	local batteryCfg = EngineConfig.BatterySystem or {}
	local coolantCfg = EngineConfig.CoolantSystem or {}
	local maintenanceCfg = EngineConfig.Maintenance or {}
	local oilCfg = EngineConfig.OilPressure or {}
	-- (Sound setup removed)
	self.State.Running.Value = false
	self.State.EngineRPM.Value = 0
	self.State.EngineRPMMaxOverride.Value = 0
	self.State.EngineTemp.Value = ambientTemp
	self.State.EngineWear.Value = tonumber(EngineConfig.EngineWear and EngineConfig.EngineWear.StartingValue) or 100
	self.State.BatteryPercent.Value = math.clamp(tonumber(batteryCfg.StartingPercent) or 100, 0, 100)
	self.State.BatteryVoltage.Value = tonumber(batteryCfg.MaxVoltage) or 14.4
	self.State.BatteryLow.Value = false
	self.State.AlternatorOn.Value = false
	self.State.CoolantLevel.Value = math.clamp(tonumber(coolantCfg.StartingLevel) or 100, 0, 100)
	self.State.CoolantPressure.Value = tonumber(coolantCfg.PressureAtIdle) or 10
	self.State.CoolantWarning.Value = false
	self.State.EngineLimpMode.Value = false
	self.State.CheckEngine.Value = false
	self.State.MaintenanceMilesRemaining.Value = tonumber(maintenanceCfg.StartingMilesRemaining) or 5000
	self.State.MaintenanceDue.Value = false
	self.State.OilPressure.Value = tonumber(oilCfg.PressureAtIdle) or 24
	self.State.OilPressureWarning.Value = false
end
function Engine:handleAction(action, payload)
	if action == "SetRPMHint" and type(payload) == "number" then
		self.RPMHintValue = payload
		self.RPMHintStamp = tick()
		return true
	end
	return false
end
function Engine:isEngineOn(state)
	if state.EngineOn and state.EngineOn:IsA("BoolValue") then
		if state.EngineOn.Value then
			return true
		end
	end
	if state.IsOn and state.IsOn:IsA("BoolValue") then
		if state.IsOn.Value then
			return true
		end
	end
	if not self._ignitionIsOnValue or not self._ignitionIsOnValue.Parent then
		local direct = self.VehicleModel and self.VehicleModel:FindFirstChild("IsOn")
		if direct and direct:IsA("BoolValue") then
			self._ignitionIsOnValue = direct
		else
			local nested = self.VehicleModel and self.VehicleModel:FindFirstChild("IsOn", true)
			if nested and nested:IsA("BoolValue") then
				self._ignitionIsOnValue = nested
			end
		end
	end
	if self._ignitionIsOnValue and self._ignitionIsOnValue:IsA("BoolValue") then
		return self._ignitionIsOnValue.Value
	end
	return false
end
function Engine:getDriverChassisValues()
	if self._driverChassisValues and self._driverChassisValues.Parent then
		return self._driverChassisValues
	end
	local occupant = self.Seat and self.Seat.Occupant
	if not occupant then
		self._driverChassisValues = nil
		return nil
	end
	local character = occupant.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then
		return nil
	end
	local chassisInterface = script.Parent
	local values = chassisInterface and chassisInterface:FindFirstChild("Values")
	if values and values:IsA("Folder") then
		self._driverChassisValues = values
		return values
	end
	return nil
end
function Engine:getChassisNumber(state, valueName)
	local values = self:getDriverChassisValues()
	local valueObj = values and values:FindFirstChild(valueName)
	local fromGui = tonumber(valueObj and valueObj.Value)
	if fromGui ~= nil then
		return fromGui
	end
	local fromState = tonumber(state[valueName] and state[valueName].Value)
	if fromState ~= nil then
		return fromState
	end
	return nil
end
function Engine:getThrottleNorm(state)
	local seatThrottleFloat = math.abs(tonumber(self.Seat and self.Seat.ThrottleFloat) or 0)
	local seatThrottleInt = math.abs(tonumber(self.Seat and self.Seat.Throttle) or 0)
	local seatThrottle = math.max(seatThrottleFloat, seatThrottleInt)
	local stateThrottle = math.abs(tonumber(state.Throttle and state.Throttle.Value) or 0)
	local guiThrottle = math.abs(self:getChassisNumber(state, "Throttle") or 0)
	return math.clamp(math.max(seatThrottle, stateThrottle, guiThrottle), 0, 1)
end
function Engine:getDamageDelta()
	local totalDamageValue = self.State.TotalDamage
	if not totalDamageValue or not totalDamageValue:IsA("NumberValue") then
		return 0
	end
	local current = math.max(0, tonumber(totalDamageValue.Value) or 0)
	local previous = math.max(0, tonumber(self._lastTotalDamage) or 0)
	self._lastTotalDamage = current
	return math.max(0, current - previous)
end
function Engine:isEngineFailed()
	local wear = math.clamp(tonumber(self.State.EngineWear and self.State.EngineWear.Value) or 100, 0, 100)
	if wear <= 0 then
		self._engineFailed = true
	end
	return self._engineFailed
end
function Engine:resolveWearRPMCap(maxRpm)
	local cfg = EngineConfig.ProgressiveFailure or {}
	local wear = math.clamp(tonumber(self.State.EngineWear and self.State.EngineWear.Value) or 100, 0, 100)
	local startWear = tonumber(cfg.RPMCapStartWear) or 75
	local minFraction = tonumber(cfg.RPMCapMinFraction) or 0.35
	if wear >= startWear then
		return maxRpm
	end
	local fraction = minFraction + (wear / math.max(1, startWear)) * (1 - minFraction)
	return maxRpm * math.clamp(fraction, minFraction, 1)
end
function Engine:resolveWearPowerFraction()
	local cfg = EngineConfig.ProgressiveFailure or {}
	local wear = math.clamp(tonumber(self.State.EngineWear and self.State.EngineWear.Value) or 100, 0, 100)
	local startWear = tonumber(cfg.PowerDropStartWear) or 60
	local minFraction = tonumber(cfg.PowerMinFraction) or 0.30
	if wear >= startWear then
		return 1
	end
	return math.clamp(minFraction + (wear / math.max(1, startWear)) * (1 - minFraction), minFraction, 1)
end
function Engine:applyMisfire(dt, rpm, throttleNorm)
	local cfg = EngineConfig.ProgressiveFailure or {}
	if cfg.Enabled == false then
		return rpm
	end
	local wear = math.clamp(tonumber(self.State.EngineWear and self.State.EngineWear.Value) or 100, 0, 100)
	local threshold = tonumber(cfg.MisfireStartWear) or 50
	if wear > threshold or throttleNorm <= 0.05 or rpm <= 0 then
		self._misfireRemaining = math.max(0, (self._misfireRemaining or 0) - (tonumber(dt) or 0))
		return rpm
	end
	if self._misfireRemaining > 0 then
		self._misfireRemaining = math.max(0, self._misfireRemaining - (tonumber(dt) or 0))
		local dropMin = tonumber(cfg.MisfireRPMDropMin) or 0.15
		local dropMax = tonumber(cfg.MisfireRPMDropMax) or 0.40
		local dropFraction = dropMin + (math.clamp((threshold - wear) / math.max(1, threshold), 0, 1) * (dropMax - dropMin))
		return math.max(0, rpm * (1 - dropFraction))
	end
	local probability = math.clamp((threshold - wear) / math.max(1, threshold), 0, 1) * (tonumber(cfg.MisfireMaxProbability) or 0.35)
	if math.random() < probability * math.clamp(tonumber(dt) or 0, 0, 1) then
		self._misfireRemaining = tonumber(cfg.MisfireDuration) or 0.3
		local dropMin = tonumber(cfg.MisfireRPMDropMin) or 0.15
		local dropMax = tonumber(cfg.MisfireRPMDropMax) or 0.40
		local dropFraction = dropMin + (math.clamp((threshold - wear) / math.max(1, threshold), 0, 1) * (dropMax - dropMin))
		return math.max(0, rpm * (1 - dropFraction))
	end
	return rpm
end
function Engine:isFreeRevCondition(state)
	local gear = self:getChassisNumber(state, "Gear")
	local clutch = self:getChassisNumber(state, "Clutch")
	if gear ~= nil and (math.abs(gear) < 0.5 or gear <= -2) then
		return true
	end
	if clutch ~= nil and clutch > 0.75 then
		return true
	end
	return false
end
function Engine:update(dt)
	local state = self.State
	local idleRpm = self:resolveIdleRPM()
	local maxRpm = self:resolveMaxRPM()
	local engineOn = self:isEngineOn(state)
	local failed = self:isEngineFailed()
	if self.GlobalConfig.AutoRunningLightsOnOccupant then
		state.Running.Value = self.Seat.Occupant ~= nil
	else
		state.Running.Value = engineOn and not failed
	end
	local rpmMaxOverride = tonumber(state.EngineRPMMaxOverride and state.EngineRPMMaxOverride.Value) or 0
	local effectiveMaxRpm = self:resolveWearRPMCap(maxRpm)
	if rpmMaxOverride > 0 then
		effectiveMaxRpm = math.min(effectiveMaxRpm, rpmMaxOverride)
	end
	if failed then
		effectiveMaxRpm = 0
	end
	local effectiveIdleRpm = math.min(idleRpm, math.max(0, effectiveMaxRpm))
	if engineOn and not failed then
		local throttleNorm = self:getThrottleNorm(state) * self:resolveWearPowerFraction()
		local speedRef = tonumber(EngineConfig.EngineState and EngineConfig.EngineState.SpeedToRPMReferenceMph) or 140
		local speedNorm = math.clamp((tonumber(state.Speed and state.Speed.Value) or 0) / math.max(1, speedRef), 0, 1)
		local freeRev = self:isFreeRevCondition(state)
		local speedInput = freeRev and 0 or (speedNorm * 0.8)
		local targetRpm = effectiveIdleRpm
		if effectiveMaxRpm > effectiveIdleRpm then
			targetRpm = effectiveIdleRpm + ((effectiveMaxRpm - effectiveIdleRpm) * math.max(throttleNorm, speedInput))
		end
		state.EngineRPM.Value = math.clamp(targetRpm, effectiveIdleRpm, effectiveMaxRpm)
		state.EngineRPM.Value = self:applyMisfire(dt, state.EngineRPM.Value, throttleNorm)
	else
		state.EngineRPM.Value = 0
	end
	if engineOn and not failed and (tick() - self.RPMHintStamp) <= 0.35 and type(self.RPMHintValue) == "number" then
		local hintedRpm = math.clamp(tonumber(self.RPMHintValue) or 0, effectiveIdleRpm, effectiveMaxRpm)
		state.EngineRPM.Value = math.max(state.EngineRPM.Value, hintedRpm)
	end
	-- (Engine sound pitch update removed)
	local tempCfg = EngineConfig.EngineTemp or {}
	if tempCfg.Enabled ~= false then
		local ambientTemp = tonumber(tempCfg.Ambient) or 80
		local normalTemp = tonumber(tempCfg.Normal) or 195
		local maxTemp = tonumber(tempCfg.Max) or 260
		local warmupRate = tonumber(tempCfg.WarmupRate) or 22
		local cooldownRate = tonumber(tempCfg.CooldownRate) or 14
		if engineOn then
			local rpmNorm = math.clamp((maxRpm > 0) and ((tonumber(state.EngineRPM.Value) or 0) / maxRpm) or 0, 0, 1)
			local targetTemp = normalTemp + (maxTemp - normalTemp) * rpmNorm
			local t = math.clamp((warmupRate * (tonumber(dt) or 0)) / math.max(1, maxTemp - ambientTemp), 0, 1)
			local engineTempNow = tonumber(state.EngineTemp.Value) or ambientTemp
			state.EngineTemp.Value = engineTempNow + (targetTemp - engineTempNow) * t
		else
			local t = math.clamp((cooldownRate * (tonumber(dt) or 0)) / math.max(1, maxTemp - ambientTemp), 0, 1)
			local engineTempNow = tonumber(state.EngineTemp.Value) or ambientTemp
			state.EngineTemp.Value = engineTempNow + (ambientTemp - engineTempNow) * t
		end
		state.EngineTemp.Value = math.clamp(tonumber(state.EngineTemp.Value) or ambientTemp, ambientTemp, maxTemp)
	end
	local batteryCfg = EngineConfig.BatterySystem or {}
	if batteryCfg.Enabled ~= false and state.BatteryPercent and state.BatteryVoltage then
		local batteryPercent = math.clamp(tonumber(state.BatteryPercent.Value) or 100, 0, 100)
		local accessoryOn = state.AccessoryOn and state.AccessoryOn.Value
		local starting = state.IgnitionStarting and state.IgnitionStarting.Value
		local drainRate = tonumber(batteryCfg.EngineOffDrainRate) or 0.05
		if engineOn then
			drainRate = -((tonumber(batteryCfg.IdleChargeRate) or 0.75) + (math.clamp((tonumber(state.EngineRPM.Value) or 0) / math.max(1, maxRpm), 0, 1) * ((tonumber(batteryCfg.RunningChargeRate) or 1.8) - (tonumber(batteryCfg.IdleChargeRate) or 0.75))))
		elseif accessoryOn or starting then
			drainRate = tonumber(batteryCfg.AccessoryDrainRate) or 0.35
		end
		batteryPercent = math.clamp(batteryPercent - (drainRate * (tonumber(dt) or 0)), 0, 100)
		state.BatteryPercent.Value = batteryPercent
		local minVoltage = tonumber(batteryCfg.MinVoltage) or 11.2
		local maxVoltage = tonumber(batteryCfg.MaxVoltage) or 14.4
		state.BatteryVoltage.Value = minVoltage + ((maxVoltage - minVoltage) * (batteryPercent / 100))
		state.AlternatorOn.Value = engineOn == true
		local lowThreshold = tonumber(batteryCfg.LowThreshold) or 25
		state.BatteryLow.Value = batteryPercent <= lowThreshold
	end
	local coolantCfg = EngineConfig.CoolantSystem or {}
	if coolantCfg.Enabled ~= false and state.CoolantLevel and state.CoolantPressure and state.CoolantWarning then
		local coolantLevel = math.clamp(tonumber(state.CoolantLevel.Value) or 100, 0, 100)
		local leakRate = math.max(0, tonumber(coolantCfg.LeakRate) or 0)
		if leakRate > 0 then
			coolantLevel = math.max(0, coolantLevel - (leakRate * (tonumber(dt) or 0)))
		end
		state.CoolantLevel.Value = coolantLevel
		local pressureIdle = tonumber(coolantCfg.PressureAtIdle) or 10
		local pressureRedline = tonumber(coolantCfg.PressureAtRedline) or 18
		local rpmNorm = math.clamp((maxRpm > 0) and ((tonumber(state.EngineRPM.Value) or 0) / maxRpm) or 0, 0, 1)
		state.CoolantPressure.Value = pressureIdle + ((pressureRedline - pressureIdle) * rpmNorm) * (coolantLevel / 100)
		local warningLevel = tonumber(coolantCfg.WarningLevel) or 25
		local criticalLevel = tonumber(coolantCfg.CriticalLevel) or 10
		local overheat = (tonumber(state.EngineTemp.Value) or 0) >= ((tonumber(tempCfg.Max) or 260) - 5)
		state.CoolantWarning.Value = coolantLevel <= warningLevel or overheat
		state.CoolantCritical = coolantLevel <= criticalLevel
	else
		state.CoolantCritical = false
	end
	local oilCfg = EngineConfig.OilPressure or {}
	if oilCfg.Enabled ~= false and state.OilPressure and state.OilPressureWarning then
		local pressureIdle = tonumber(oilCfg.PressureAtIdle) or 24
		local pressureRedline = tonumber(oilCfg.PressureAtRedline) or 62
		local wearPenaltyScale = tonumber(oilCfg.WearPenaltyScale) or 0.35
		local rpmNorm = math.clamp((maxRpm > 0) and ((tonumber(state.EngineRPM.Value) or 0) / maxRpm) or 0, 0, 1)
		local wearNorm = math.clamp((tonumber(state.EngineWear and state.EngineWear.Value) or 100) / 100, 0, 1)
		local basePressure = pressureIdle + ((pressureRedline - pressureIdle) * rpmNorm)
		state.OilPressure.Value = math.max(0, basePressure * (1 - ((1 - wearNorm) * wearPenaltyScale)))
		local warningThreshold = tonumber(oilCfg.WarningThreshold) or 18
		state.OilPressureWarning.Value = engineOn and state.OilPressure.Value <= warningThreshold or false
	end
	local wearCfg = EngineConfig.EngineWear or {}
	if wearCfg.Enabled ~= false and state.EngineWear then
		self.EngineWearAccumulator += tonumber(dt) or 0
		local updateRate = math.max(0.05, tonumber(wearCfg.UpdateRate) or 1)
		if self.EngineWearAccumulator >= updateRate then
			self.EngineWearAccumulator = 0
			local wearDelta = 0
			if engineOn then
				local speedNorm = math.clamp((tonumber(state.Speed and state.Speed.Value) or 0) / 100, 0, 1)
				local throttleNorm = self:getThrottleNorm(state)
				wearDelta = wearDelta + ((tonumber(wearCfg.BaseRate) or 0.02) * (0.3 + throttleNorm * 0.5 + speedNorm * 0.7))
				if state.CoolantCritical then
					wearDelta = wearDelta + (tonumber(wearCfg.CoolantCriticalWearRate) or 0.15)
				end
				local oilPressure = tonumber(state.OilPressure and state.OilPressure.Value) or 0
				local oilCriticalThreshold = tonumber((EngineConfig.OilPressure or {}).CriticalThreshold) or 8
				if oilPressure <= oilCriticalThreshold then
					wearDelta = wearDelta + (tonumber(wearCfg.OilCriticalWearRate) or 0.12)
				end
				if state.MaintenanceDue and state.MaintenanceDue.Value then
					wearDelta = wearDelta + (tonumber(wearCfg.MaintenanceOverdueWearRate) or 0.05)
				end
				local damageDelta = self:getDamageDelta()
				if damageDelta > 0 then
					wearDelta = wearDelta + (damageDelta * (tonumber(wearCfg.CollisionWearScale) or 0.08))
				end
				local engineTemp = tonumber(state.EngineTemp and state.EngineTemp.Value) or 0
				local maxTemp = tonumber((EngineConfig.EngineTemp or {}).Max) or 260
				if engineTemp >= maxTemp then
					wearDelta = wearDelta + (tonumber(wearCfg.OverheatWearRate) or 0.10)
				end
			end
			state.EngineWear.Value = math.max(0, (tonumber(state.EngineWear.Value) or 0) - wearDelta)
			if state.EngineWear.Value <= 0 and (EngineConfig.EngineFailure or {}).Enabled ~= false then
				self._engineFailed = true
			end
		end
	end
	local maintenanceCfg = EngineConfig.Maintenance or {}
	if maintenanceCfg.Enabled ~= false and state.MaintenanceMilesRemaining and state.MaintenanceDue then
		self.MaintenanceAccumulator += tonumber(dt) or 0
		if self.MaintenanceAccumulator >= 1 then
			self.MaintenanceAccumulator = 0
			local speed = math.max(0, tonumber(state.Speed and state.Speed.Value) or 0)
			local milesPerSecondAt60 = tonumber(maintenanceCfg.MilesPerSecondAt60Mph) or (1 / 60)
			local milesDelta = (speed / 60) * milesPerSecondAt60
			if engineOn and milesDelta > 0 then
				state.MaintenanceMilesRemaining.Value = state.MaintenanceMilesRemaining.Value - milesDelta
			end
			local dueThreshold = tonumber(maintenanceCfg.ServiceDueThreshold) or 0
			state.MaintenanceDue.Value = (tonumber(state.MaintenanceMilesRemaining.Value) or 0) <= dueThreshold
		end
	end
	local limpCfg = EngineConfig.LimpMode or {}
	if limpCfg.Enabled ~= false and state.EngineLimpMode and state.CheckEngine and state.EngineRPMMaxOverride then
		local criticalBattery = (tonumber(state.BatteryPercent and state.BatteryPercent.Value) or 100) <= (tonumber((EngineConfig.BatterySystem or {}).CriticalThreshold) or 10)
		local criticalCoolant = state.CoolantCritical == true
		local overheat = (tonumber(state.EngineTemp and state.EngineTemp.Value) or 0) >= (tonumber(tempCfg.Max) or 260)
		local criticalOil = (tonumber(state.OilPressure and state.OilPressure.Value) or 999) <= (tonumber((EngineConfig.OilPressure or {}).CriticalThreshold) or 8)
		local maintenanceDue = state.MaintenanceDue and state.MaintenanceDue.Value or false
		local fuelLimp = state.FuelLimpMode and state.FuelLimpMode.Value or false
		local shouldLimp =
			(limpCfg.TriggerOnFuelLimp ~= false and fuelLimp)
			or (limpCfg.TriggerOnLowOilPressure ~= false and criticalOil)
			or (limpCfg.TriggerOnCriticalBattery ~= false and criticalBattery)
			or (limpCfg.TriggerOnCriticalCoolant ~= false and criticalCoolant)
			or (limpCfg.TriggerOnOverheat ~= false and overheat)
			or (limpCfg.TriggerOnMaintenanceDue == true and maintenanceDue)
		state.EngineLimpMode.Value = shouldLimp
		state.CheckEngine.Value =
			(state.BatteryLow and state.BatteryLow.Value or false)
			or maintenanceDue
			or shouldLimp
		local requestedCap = shouldLimp and math.max(0, tonumber(limpCfg.MaxRPM) or 2800) or 0
		local existingCap = tonumber(state.EngineRPMMaxOverride.Value) or 0
		if requestedCap > 0 then
			state.EngineRPMMaxOverride.Value = (existingCap > 0) and math.min(existingCap, requestedCap) or requestedCap
		elseif state.FuelLimpMode == nil or state.FuelLimpMode.Value ~= true then
			state.EngineRPMMaxOverride.Value = 0
		end
	end
end
function Engine.getConfig()
	return EngineConfig
end
return Engine