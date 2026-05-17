
-- V O E   P L U G I N S • Exhaust
-- DATE (UTC):
--
-- DESCRIPTION:
-- Plugin entry point for exhaust pipe motion.
-- Applies Motor6D-driven shake to tagged exhaust assemblies based on engine RPM.
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)
-- - Clean, modular, no deprecated code
--====================================================================
-- Module Requires
--====================================================================
local ExhaustConfig = require(script:WaitForChild("Config"))
local ExhaustTags = require(script:WaitForChild("Tags"))
local PartAccess = require(script:WaitForChild("PartAccess"))

if ExhaustConfig and ExhaustConfig.Enabled == false then
	warn("[Exhaust] Plugin disabled via config")
	return
end

--====================================================================
-- Services
--====================================================================
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
local Exhaust = {}
Exhaust.__index = Exhaust

--====================================================================
-- Helper Functions
--====================================================================

local function debugLog(category, message)
	if ExhaustConfig.Debug and ExhaustConfig.Debug.Enabled then
		print(string.format("[Exhaust][%s] %s", category, message))
	end
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

function Exhaust.getPluginInfo()
	return {
		Name = ExhaustTags.Name,
		Actions = {},
		StateValues = {},
	}
end

function Exhaust.create(context)
	local partAccess = PartAccess.new(context.CollectionService, context.VehicleModel)
	return setmetatable({
		State = context.State,
		ValuesFolder = context.Values,
		PluginContainer = context.PluginContainer,
		GlobalConfig = context.Config,
		VehicleModel = context.VehicleModel,
		Seat = context.Seat,
		TaggedInstances = function(tagName)
			return partAccess:taggedInstances(tagName)
		end,
		ResolveBasePart = function(inst)
			return PartAccess.resolveBasePart(inst)
		end,
		ExhaustTime = 0,
	}, Exhaust)
end

function Exhaust:collectTaggedParts(tagName, resolveFn)
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

function Exhaust:getDriveSeat()
	if self.Seat and self.Seat:IsA("BasePart") then
		return self.Seat
	end
	if self.VehicleModel then
		local driveSeat = self.VehicleModel:FindFirstChild("DriveSeat")
		if driveSeat and driveSeat:IsA("BasePart") then
			return driveSeat
		end
		local vehicleSeat = self.VehicleModel:FindFirstChildWhichIsA("VehicleSeat", true)
		if vehicleSeat then
			return vehicleSeat
		end
		local seat = self.VehicleModel:FindFirstChildWhichIsA("Seat", true)
		if seat then
			return seat
		end
	end
	return nil
end

function Exhaust:ensureExhaustMotor(rootPart, roleName)
	local motorName = "VOE_ExhaustMotor_" .. roleName
	local existing = rootPart:FindFirstChild(motorName)
	local pivot = rootPart:FindFirstChild(ExhaustTags.Optional.MotorPivot)
	local pivotCFrame = (pivot and pivot:IsA("Attachment")) and pivot.WorldCFrame or rootPart.CFrame
	if not pivot or not pivot:IsA("Attachment") then
		debugLog("Setup", "No VOE_MotorPivot attachment found on root " .. rootPart:GetFullName() .. "; using root CFrame")
	end

	local seatPart = self:getDriveSeat()
	if not seatPart then
		debugLog("Setup", "No drive seat found for exhaust motor")
		return nil
	end

	local seatAttachmentName = "VOE_ExhaustMotorPivot"
	local seatAttachment = seatPart:FindFirstChild(seatAttachmentName)
	if not seatAttachment then
		seatAttachment = Instance.new("Attachment")
		seatAttachment.Name = seatAttachmentName
		seatAttachment.Parent = seatPart
		debugLog("Setup", "Created exhaust seat attachment " .. seatAttachmentName .. " on " .. seatPart:GetFullName())
	end

	seatAttachment.WorldCFrame = pivotCFrame
	debugLog("Setup", "Aligned seat attachment " .. seatAttachmentName .. " to pivot at " .. tostring(pivotCFrame))

	local function alignMotor(motor)
		motor.Part0 = seatPart
		motor.Part1 = rootPart
		motor.C0 = seatPart.CFrame:ToObjectSpace(seatAttachment.WorldCFrame)
		motor.C1 = rootPart.CFrame:ToObjectSpace(pivotCFrame)
		motor.Parent = rootPart
	end

	if existing and existing:IsA("Motor6D") then
		debugLog("Setup", "Reusing existing exhaust motor: " .. motorName)
		alignMotor(existing)
		return existing
	end

	local motor = Instance.new("Motor6D")
	motor.Name = motorName
	alignMotor(motor)
	debugLog("Setup", "Created exhaust motor " .. motorName .. " between " .. seatPart:GetFullName() .. " and " .. rootPart:GetFullName())
	return motor
end

function Exhaust:setupExhaust()
	self.ExhaustAssemblies = {}
	local roots = self:collectTaggedParts(ExhaustTags.Required.Exhaust.Root, self.ResolveRootPart)
	local parts = self:collectTaggedParts(ExhaustTags.Required.Exhaust.Part, self.ResolveBasePart)
	for index, rootPart in ipairs(roots) do
		local partSet = {[rootPart] = true}
		local allParts = {rootPart}
		for _, part in ipairs(parts) do
			if part ~= rootPart then
				partSet[part] = true
				table.insert(allParts, part)
			end
		end
		ensureWeldedToRoot(rootPart, allParts, "VOE_ExhaustWeld")
		local motor = self:ensureExhaustMotor(rootPart, "Exhaust" .. tostring(index))
		table.insert(self.ExhaustAssemblies, {
			Part = rootPart,
			Motor = motor,
		})
	end
	debugLog("Setup", "Initialized " .. #self.ExhaustAssemblies .. " exhaust assemblies")
end

function Exhaust:applyExhaustShake(dt)
	local exhaustCfg = ExhaustConfig.ExhaustMotion or {}
	if exhaustCfg.Enabled == false or #self.ExhaustAssemblies == 0 then
		return
	end

	local function readStateNumber(name)
		if self.State and self.State[name] then
			return tonumber(self.State[name].Value)
		end
		if self.ValuesFolder then
			local value = self.ValuesFolder:FindFirstChild(name)
			if value and value:IsA("NumberValue") then
				return tonumber(value.Value)
			end
		end
		if self.PluginContainer then
			local legacyValues = self.PluginContainer:FindFirstChild("Values")
			if legacyValues and legacyValues:IsA("Folder") then
				local value = legacyValues:FindFirstChild(name)
				if value and value:IsA("NumberValue") then
					return tonumber(value.Value)
				end
			end
		end
		if self.VehicleModel then
			local stateFolder = self.VehicleModel:FindFirstChild("VOE_State")
			if stateFolder then
				local value = stateFolder:FindFirstChild(name)
				if value and value:IsA("NumberValue") then
					return tonumber(value.Value)
				end
			end
			local legacy = self.VehicleModel:FindFirstChild(name, true)
			if legacy and legacy:IsA("NumberValue") then
				return tonumber(legacy.Value)
			end
		end
		return nil
	end

	local engineRpm = math.max(0, readStateNumber("EngineRPM") or 0)
	local maxRpm = tonumber(readStateNumber("EngineRPMMaxOverride")) or 0
	if maxRpm <= 0 then
		maxRpm = 7000
	end

	local rpmNorm = math.clamp(engineRpm / math.max(1, maxRpm), 0, 1)
	if rpmNorm <= 0 then
		debugLog("Shake", "EngineRPM normalized to 0; EngineRPM=" .. tostring(engineRpm) .. " max=" .. tostring(maxRpm))
	end
	self.ExhaustTime += tonumber(dt) or 0

	for idx, assembly in ipairs(self.ExhaustAssemblies) do
		if assembly.Motor and assembly.Motor.Parent and assembly.Part and assembly.Part.Parent then
			local part = assembly.Part
			local freqIdle = tonumber(part:GetAttribute(ExhaustTags.Optional.ShakeFreqIdle)) or tonumber(exhaustCfg.FrequencyAtIdle) or 10
			local freqRedline = tonumber(part:GetAttribute(ExhaustTags.Optional.ShakeFreqRedline)) or tonumber(exhaustCfg.FrequencyAtRedline) or 28
			local frequency = freqIdle + (freqRedline - freqIdle) * rpmNorm
			local phase = self.ExhaustTime * frequency * math.pi * 2
			local moveAxis = axisVector(part:GetAttribute(ExhaustTags.Optional.ShakeAxis), exhaustCfg.Axis or "X")
			local rotateAxis = axisVector(part:GetAttribute(ExhaustTags.Optional.ShakeRotateAxis), exhaustCfg.RotateAxis or "Z")
			local amplitudeStuds = tonumber(part:GetAttribute(ExhaustTags.Optional.ShakeAmplitudeStuds)) or tonumber(exhaustCfg.AmplitudeStuds) or 0.015
			local amplitudeDegrees = tonumber(part:GetAttribute(ExhaustTags.Optional.ShakeAmplitudeDegrees)) or tonumber(exhaustCfg.AmplitudeDegrees) or 1.25
			local offset = math.sin(phase + idx * 0.65)
			local translation = moveAxis * amplitudeStuds * rpmNorm * offset
			local rotation = CFrame.fromAxisAngle(rotateAxis, math.rad(amplitudeDegrees) * rpmNorm * offset)
			assembly.Motor.Transform = CFrame.new(translation) * rotation
		end
	end
end

function Exhaust:setup()
	self:setupExhaust()
end

function Exhaust:handleAction(action, payload)
	return false
end

function Exhaust:update(dt)
	self:applyExhaustShake(dt)
end

function Exhaust.getConfig()
	return ExhaustConfig
end

return Exhaust
