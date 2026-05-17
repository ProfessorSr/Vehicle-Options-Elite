
-- V O E   P L U G I N S • Spotlights
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles spotlight on/off state and arm/lamp rotation.
-- Left and Right spotlights each toggle independently.
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)
-- - Arm/lamp/base rotation drives hinge constraints created by VOE_RigBootstrap
-- - Keybinds configured in Config

--====================================================================
-- Module Requires
--====================================================================

local Config = require(script:WaitForChild("Config"))
local Tags = require(script:WaitForChild("Tags"))
local PluginSounds = require(script:WaitForChild("Sounds"))
local Interface = require(script:WaitForChild("Interface"))

if Config and Config.Enabled == false then
	warn("[Spotlights] Plugin disabled via config")
	return
end

--====================================================================
-- Services
--====================================================================

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = RunService:IsClient() and game:GetService("UserInputService") or nil

--====================================================================
-- Configuration
--====================================================================

local DEBUG_CONFIG = Config.Debug or {}
local ROLE_ORDER = {"Left", "Right"}
local STATE_DEFS = {
	SpotlightLeft = { ClassName = "BoolValue", Default = false },
	SpotlightRight = { ClassName = "BoolValue", Default = false },
	SpotlightLeftBaseAngle = { ClassName = "NumberValue", Default = 0 },
	SpotlightLeftArmAngle = { ClassName = "NumberValue", Default = 0 },
	SpotlightLeftLampAngle = { ClassName = "NumberValue", Default = 0 },
	SpotlightRightBaseAngle = { ClassName = "NumberValue", Default = 0 },
	SpotlightRightArmAngle = { ClassName = "NumberValue", Default = 0 },
	SpotlightRightLampAngle = { ClassName = "NumberValue", Default = 0 },
}
local DEFAULT_ROTATION_STEP_DEGREES = 5

--====================================================================
-- State Management
--====================================================================

local Vehicle = nil
local StateValues = {}
local MappedLights = {}
local StateContainer = nil
local RotationStates = {} -- arm/lamp rotation state per role

--====================================================================
-- Context Resolution
--====================================================================

local function findRuntimeCarAndValues()
	local pluginContainer = script.Parent
	local carValue = pluginContainer:FindFirstChild("Car")
	local valuesFolder = pluginContainer:FindFirstChild("Values")

	if carValue and carValue:IsA("ObjectValue") and carValue.Value and carValue.Value:IsA("Model") then
		local vehicle = carValue.Value
		local voeState = vehicle:FindFirstChild("VOE_State")
		if voeState then
			return vehicle, voeState
		end
		return vehicle, valuesFolder
	end
	return nil, valuesFolder
end

--====================================================================
-- Helper Functions
--====================================================================

local function setupPluginSounds(vehicle)
	local soundsModule = PluginSounds
	if not soundsModule or not soundsModule.setupSounds then return end
	if not vehicle then return end
	local body = vehicle:FindFirstChild("Body")
	if not body then body = vehicle:WaitForChild("Body", 10) end
	if not body then return end
	local soundParent = body:FindFirstChild("Sounds")
	if not soundParent then soundParent = body:WaitForChild("Sounds", 10) end
	if not soundParent then
		soundParent = Instance.new("Folder")
		soundParent.Name = "Sounds"
		soundParent.Parent = body
	end
	soundsModule.setupSounds(soundParent)
end

local function bootstrapPluginSounds()
	local carValue = script.Parent:FindFirstChild("Car")
	if not carValue or not carValue:IsA("ObjectValue") then return end
	local function apply()
		local vehicle = carValue.Value
		if vehicle and vehicle:IsA("Model") then setupPluginSounds(vehicle) end
	end
	apply()
	carValue.Changed:Connect(apply)
end

bootstrapPluginSounds()

local function debugLog(category, message)
	if not DEBUG_CONFIG.Enabled then return end
	print(string.format("[Spotlights][%s] %s", category, message))
end

local function ensureStateValue(container, name, className, defaultValue)
	if not container then return nil end
	local values = container
	if not container:IsA("Folder") then
		values = container:FindFirstChild("Values")
		if not values then
			values = Instance.new("Folder")
			values.Name = "Values"
			values.Parent = container
		end
	end
	local existing = values:FindFirstChild(name)
	if existing then return existing end
	local value = Instance.new(className)
	value.Name = name
	value.Parent = values
	value:SetAttribute("VOE_Owner", "Spotlights")
	value:SetAttribute("VOE_Type", "State")
	if className == "BoolValue" then value.Value = defaultValue or false
	elseif className == "IntValue" then value.Value = defaultValue or 0
	elseif className == "NumberValue" then value.Value = defaultValue or 0
	elseif className == "StringValue" then value.Value = defaultValue or "" end
	return value
end

local function initializeStateValues()
	if not StateContainer then return end
	for stateName, spec in pairs(STATE_DEFS) do
		StateValues[stateName] = ensureStateValue(StateContainer, stateName, spec.ClassName, spec.Default)
	end
end

--====================================================================
-- Light Mapping
--====================================================================

local function resolveBasePart(inst)
	if inst:IsA("BasePart") then return inst
	elseif inst:IsA("Model") then return inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart")
	elseif inst:IsA("Attachment") then return inst.Parent
	elseif inst:IsA("Light") then
		local parent = inst.Parent
		if parent and parent:IsA("Attachment") then return parent.Parent end
		return parent
	end
	return nil
end

local function ensureSpotlight(part, profile)
	local attachmentName = "VOE_LightAttachment_Spotlight"
	local attachment = part:FindFirstChild(attachmentName)
	if not attachment or not attachment:IsA("Attachment") then
		attachment = Instance.new("Attachment")
		attachment.Name = attachmentName
		attachment.Parent = part
	end
	local spot = attachment:FindFirstChild("VOE_SpotLight")
	if not spot or not spot:IsA("SpotLight") then
		if spot then spot.Parent = nil end
		spot = Instance.new("SpotLight")
		spot.Name = "VOE_SpotLight"
		spot.Parent = attachment
	end
	spot.Brightness = profile.Brightness or 4
	spot.Range = profile.Range or 60
	spot.Angle = profile.Angle or 45
	spot.Color = profile.Color or Color3.fromRGB(255, 255, 230)
	spot.Shadows = profile.Shadows ~= false
	spot.Enabled = false
	return spot
end

local function mapLightsByTag(tagName, profile)
	if not tagName or tagName == "" then return {} end
	local list = {}
	for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
		local part = resolveBasePart(inst)
		if part and Vehicle and part:IsDescendantOf(Vehicle) then
			local spot = ensureSpotlight(part, profile)
			table.insert(list, {
				Spot = spot,
				Part = part,
				Profile = profile,
				OrigMaterial = part.Material,
				OrigColor = part.Color,
			})
		end
	end
	return list
end

local function setupLightMapping()
	if not Vehicle then return end
	local profile = Config.Lights and Config.Lights.Spotlight or {}
	MappedLights.Left = mapLightsByTag(Tags.Required.SpotlightLeft_Tag, profile)
	MappedLights.Right = mapLightsByTag(Tags.Required.SpotlightRight_Tag, profile)
end

--====================================================================
-- Light Control
--====================================================================

local function enableLights(lightList)
	if not lightList then return end
	for _, entry in ipairs(lightList) do
		if entry.Spot and entry.Spot.Parent then
			entry.Spot.Enabled = true
			if entry.Part and entry.Profile then
				entry.Part.Material = Enum.Material.Neon
				entry.Part.Color = entry.Profile.Color or entry.Part.Color
			end
		end
	end
end

local function disableLights(lightList)
	if not lightList then return end
	for _, entry in ipairs(lightList) do
		if entry.Spot and entry.Spot.Parent then
			entry.Spot.Enabled = false
			if entry.Part then
				entry.Part.Material = entry.OrigMaterial
				entry.Part.Color = entry.OrigColor
			end
		end
	end
end

local function applySpotlightState()
	for _, id in ipairs(ROLE_ORDER) do
		local stateName = "Spotlight" .. id
		local stateValue = StateValues[stateName]
		if stateValue and stateValue.Value then
			enableLights(MappedLights[id])
		else
			disableLights(MappedLights[id])
		end
	end
end

--====================================================================
-- Hinge Rotation
--====================================================================

local function findAttachmentByName(vehicle, name)
	if not vehicle or not name or name == "" then return nil end
	for _, descendant in ipairs(vehicle:GetDescendants()) do
		if descendant:IsA("Attachment") and descendant.Name == name then
			return descendant
		end
	end
	return nil
end

local function findHinge(part, name)
	if part and part:IsA("BasePart") then
		local byName = part:FindFirstChild(name)
		if byName and byName:IsA("HingeConstraint") then
			return byName
		end
	end
	if Vehicle then
		for _, inst in ipairs(Vehicle:GetDescendants()) do
			if inst.Name == name and inst:IsA("HingeConstraint") then
				return inst
			end
		end
	end
	return nil
end

local function applyHingeDefaults(hinge)
	if not hinge then return end
	hinge.ActuatorType = Enum.ActuatorType.Servo
	hinge.AngularSpeed = Config.RotationSpeed or hinge.AngularSpeed or 5
	hinge.ServoMaxTorque = Config.RotationTorque or hinge.ServoMaxTorque or 15000
	hinge.LimitsEnabled = false
end

local function getMotionConfig(sideConfig, segmentName, part)
	local defaults = (Config.MotionDefaults and Config.MotionDefaults[segmentName]) or {}
	local segmentConfig = (sideConfig and sideConfig[segmentName]) or {}
	return {
		MinAngle = tonumber(part and part:GetAttribute(Tags.Optional.MinAngleAttribute))
			or tonumber(part and part:GetAttribute("VOE_" .. segmentName .. "MinAngle"))
			or tonumber(segmentConfig.MinAngle)
			or tonumber(defaults.MinAngle)
			or -180,
		MaxAngle = tonumber(part and part:GetAttribute(Tags.Optional.MaxAngleAttribute))
			or tonumber(part and part:GetAttribute("VOE_" .. segmentName .. "MaxAngle"))
			or tonumber(segmentConfig.MaxAngle)
			or tonumber(defaults.MaxAngle)
			or 180,
		StepAngle = tonumber(part and part:GetAttribute(Tags.Optional.RotationStepAttribute))
			or tonumber(part and part:GetAttribute("VOE_" .. segmentName .. "StepAngle"))
			or tonumber(segmentConfig.StepAngle)
			or tonumber(defaults.StepAngle)
			or DEFAULT_ROTATION_STEP_DEGREES,
		Speed = tonumber(part and part:GetAttribute(Tags.Optional.OpenSpeedAttribute))
			or tonumber(segmentConfig.Speed)
			or tonumber(Config.RotationSpeed)
			or 5,
		Torque = tonumber(part and part:GetAttribute(Tags.Optional.OpenTorqueAttribute))
			or tonumber(segmentConfig.Torque)
			or tonumber(Config.RotationTorque)
			or 15000,
	}
end

local function clampAngle(angle, motion)
	local minAngle = tonumber(motion and motion.MinAngle) or -180
	local maxAngle = tonumber(motion and motion.MaxAngle) or 180
	if minAngle > maxAngle then
		minAngle, maxAngle = maxAngle, minAngle
	end
	return math.clamp(angle, minAngle, maxAngle)
end

local function setupRotation()
	if not Vehicle then return end
	local spotCfg = Config.Spotlights or {}
	for _, id in ipairs(ROLE_ORDER) do
		local cfg = spotCfg[id]
		if cfg then
			local baseAttachment = findAttachmentByName(Vehicle, cfg.baseAttachment or "")
			local armAttachment = findAttachmentByName(Vehicle, cfg.armAttachment or "")
			local lampAttachment = findAttachmentByName(Vehicle, cfg.lampAttachment or "")

			-- The arm/lamp/base parts are the parent parts of the attachments
			local basePart = baseAttachment and baseAttachment.Parent or nil
			local armPart = armAttachment and armAttachment.Parent or nil
			local lampPart = lampAttachment and lampAttachment.Parent or nil

			local baseHinge = findHinge(basePart, "VOE_Spotlight_" .. id .. "_BaseHinge")
			local armHinge = findHinge(armPart, "VOE_Spotlight_" .. id .. "_ArmHinge")
			local lampHinge = findHinge(lampPart, "VOE_Spotlight_" .. id .. "_LampHinge")

			basePart = (basePart and basePart:IsA("BasePart") and basePart) or (baseHinge and baseHinge.Parent)
			armPart = (armPart and armPart:IsA("BasePart") and armPart) or (armHinge and armHinge.Parent)
			lampPart = (lampPart and lampPart:IsA("BasePart") and lampPart) or (lampHinge and lampHinge.Parent)

			local baseMotion = getMotionConfig(cfg, "Base", basePart)
			local armMotion = getMotionConfig(cfg, "Arm", armPart)
			local lampMotion = getMotionConfig(cfg, "Lamp", lampPart)

			RotationStates[id] = {
				baseAttachment = baseAttachment,
				armAttachment = armAttachment,
				lampAttachment = lampAttachment,
				basePart = basePart and basePart:IsA("BasePart") and basePart or nil,
				armPart = armPart and armPart:IsA("BasePart") and armPart or nil,
				lampPart = lampPart and lampPart:IsA("BasePart") and lampPart or nil,
				baseHinge = baseHinge,
				armHinge = armHinge,
				lampHinge = lampHinge,
				baseMotion = baseMotion,
				armMotion = armMotion,
				lampMotion = lampMotion,
				baseAngle = clampAngle((StateValues["Spotlight" .. id .. "BaseAngle"] and StateValues["Spotlight" .. id .. "BaseAngle"].Value) or 0, baseMotion),
				armAngle = clampAngle((StateValues["Spotlight" .. id .. "ArmAngle"] and StateValues["Spotlight" .. id .. "ArmAngle"].Value) or 0, armMotion),
				lampAngle = clampAngle((StateValues["Spotlight" .. id .. "LampAngle"] and StateValues["Spotlight" .. id .. "LampAngle"].Value) or 0, lampMotion),
				initialBaseCFrame = basePart and basePart:IsA("BasePart") and basePart.CFrame or nil,
				initialArmCFrame = armPart and armPart:IsA("BasePart") and armPart.CFrame or nil,
				initialLampCFrame = lampPart and lampPart:IsA("BasePart") and lampPart.CFrame or nil,
			}

			applyHingeDefaults(RotationStates[id].baseHinge)
			applyHingeDefaults(RotationStates[id].armHinge)
			applyHingeDefaults(RotationStates[id].lampHinge)
			if RotationStates[id].baseHinge then
				RotationStates[id].baseHinge.AngularSpeed = baseMotion.Speed
				RotationStates[id].baseHinge.ServoMaxTorque = baseMotion.Torque
				RotationStates[id].baseHinge.TargetAngle = RotationStates[id].baseAngle
			end
			if RotationStates[id].armHinge then
				RotationStates[id].armHinge.AngularSpeed = armMotion.Speed
				RotationStates[id].armHinge.ServoMaxTorque = armMotion.Torque
				RotationStates[id].armHinge.TargetAngle = RotationStates[id].armAngle
			end
			if RotationStates[id].lampHinge then
				RotationStates[id].lampHinge.AngularSpeed = lampMotion.Speed
				RotationStates[id].lampHinge.ServoMaxTorque = lampMotion.Torque
				RotationStates[id].lampHinge.TargetAngle = RotationStates[id].lampAngle
			end

			debugLog("Setup", id .. ": base=" .. (baseAttachment and baseAttachment.Name or "nil")
				.. ", arm=" .. (armAttachment and armAttachment.Name or "nil")
				.. ", lamp=" .. (lampAttachment and lampAttachment.Name or "nil")
				.. ", baseHinge=" .. (RotationStates[id].baseHinge and RotationStates[id].baseHinge.Name or "nil")
				.. ", armHinge=" .. (RotationStates[id].armHinge and RotationStates[id].armHinge.Name or "nil")
				.. ", lampHinge=" .. (RotationStates[id].lampHinge and RotationStates[id].lampHinge.Name or "nil")
				.. ", baseRange=" .. tostring(baseMotion.MinAngle) .. ".." .. tostring(baseMotion.MaxAngle)
				.. ", armRange=" .. tostring(armMotion.MinAngle) .. ".." .. tostring(armMotion.MaxAngle)
				.. ", lampRange=" .. tostring(lampMotion.MinAngle) .. ".." .. tostring(lampMotion.MaxAngle))
		end
	end
end

local function rotateHinge(state, hingeKey, angleKey, motionKey, deltaDegrees)
	local hinge = state[hingeKey]
	if not hinge or not hinge.Parent then return end
	state[angleKey] = clampAngle((state[angleKey] or 0) + deltaDegrees, state[motionKey])
	hinge.TargetAngle = state[angleKey]
end

local function rotateArm(id, deltaDegrees)
	local state = RotationStates[id]
	if not state then return end
	rotateHinge(state, "armHinge", "armAngle", "armMotion", deltaDegrees)
	if StateValues["Spotlight" .. id .. "ArmAngle"] then
		StateValues["Spotlight" .. id .. "ArmAngle"].Value = state.armAngle
	end
end

local function rotateLamp(id, deltaDegrees)
	local state = RotationStates[id]
	if not state then return end
	rotateHinge(state, "lampHinge", "lampAngle", "lampMotion", deltaDegrees)
	if StateValues["Spotlight" .. id .. "LampAngle"] then
		StateValues["Spotlight" .. id .. "LampAngle"].Value = state.lampAngle
	end
end

local function rotateBase(id, deltaDegrees)
	local state = RotationStates[id]
	if not state then return end
	rotateHinge(state, "baseHinge", "baseAngle", "baseMotion", deltaDegrees)
	if StateValues["Spotlight" .. id .. "BaseAngle"] then
		StateValues["Spotlight" .. id .. "BaseAngle"].Value = state.baseAngle
	end
end

local function keybindMatches(input, keybind)
	if not input or not keybind then
		return false
	end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return false
	end
	local keyCode = input.KeyCode
	if not keyCode then
		return false
	end
	if typeof(keybind) == "EnumItem" then
		return keyCode == keybind or keyCode.Name == keybind.Name
	elseif typeof(keybind) == "string" then
		return keyCode.Name == keybind
	end
	return false
end

--====================================================================
-- Keybind Handling
--====================================================================

local function handleKeybind(input, gameProcessed)
	if gameProcessed then return end
	local keybinds = Config.Keybinds or {}

	-- On/off toggles
	if keybindMatches(input, keybinds.ToggleSpotlightLeft) then
		if StateValues.SpotlightLeft then
			StateValues.SpotlightLeft.Value = not StateValues.SpotlightLeft.Value
			debugLog("Input", "SpotlightLeft " .. (StateValues.SpotlightLeft.Value and "ON" or "OFF"))
		end
		return
	elseif keybindMatches(input, keybinds.ToggleSpotlightRight) then
		if StateValues.SpotlightRight then
			StateValues.SpotlightRight.Value = not StateValues.SpotlightRight.Value
			debugLog("Input", "SpotlightRight " .. (StateValues.SpotlightRight.Value and "ON" or "OFF"))
		end
		return
	end

	-- Arm/lamp rotation keybinds
	local spotCfg = Config.Spotlights or {}
	for _, id in ipairs(ROLE_ORDER) do
		local cfg = spotCfg[id]
		if cfg then
			local armKeyName = cfg.armKey
			local armClockwiseKey = cfg.armClockwiseKey
			local lampKeyName = cfg.lampKey
			local baseKeyName = cfg.baseKey
			local baseCounterKeyName = cfg.baseCounterKey
			if armKeyName and keybindMatches(input, armKeyName) and RotationStates[id] then
				rotateArm(id, RotationStates[id].armMotion.StepAngle)
				return
			elseif armClockwiseKey and keybindMatches(input, armClockwiseKey) and RotationStates[id] then
				rotateArm(id, -RotationStates[id].armMotion.StepAngle)
				return
			elseif lampKeyName and keybindMatches(input, lampKeyName) and RotationStates[id] then
				rotateLamp(id, RotationStates[id].lampMotion.StepAngle)
				return
			elseif baseKeyName and keybindMatches(input, baseKeyName) and RotationStates[id] then
				rotateBase(id, RotationStates[id].baseMotion.StepAngle)
				return
			elseif baseCounterKeyName and keybindMatches(input, baseCounterKeyName) and RotationStates[id] then
				rotateBase(id, -RotationStates[id].baseMotion.StepAngle)
				return
			end
		end
	end
end

--====================================================================
-- Startup
--====================================================================

local function startup()
	-- Wait for Car ObjectValue to be set
	local pluginContainer = script.Parent
	local carValue = pluginContainer:FindFirstChild("Car")
	if not carValue then
		carValue = pluginContainer:WaitForChild("Car", 15)
	end

	if carValue then
		local startTime = tick()
		while not carValue.Value and (tick() - startTime) < 10 do
			task.wait(0.1)
		end
	end

	local runtimeCar, runtimeValues = findRuntimeCarAndValues()
	Vehicle = runtimeCar
	StateContainer = runtimeValues or Vehicle
	setupPluginSounds(Vehicle)

	if not Vehicle then
		warn("[Spotlights] Could not find vehicle model")
		return
	end
	if not StateContainer then
		warn("[Spotlights] Could not resolve state container")
		return
	end

	initializeStateValues()
	setupLightMapping()
	setupRotation()

	-- Connect state change listeners
	for _, id in ipairs(ROLE_ORDER) do
		local stateName = "Spotlight" .. id
		if StateValues[stateName] then
			StateValues[stateName].Changed:Connect(function()
				applySpotlightState()
			end)
		end
	end

	if UserInputService then
		UserInputService.InputBegan:Connect(handleKeybind)
	end

	applySpotlightState()

	-- Create the spotlight control GUI
	Interface.create(script.Parent, {
		StateValues = StateValues,
		RotationStates = RotationStates,
		rotateBase = rotateBase,
		rotateArm = rotateArm,
		ROLE_ORDER = ROLE_ORDER,
		debugLog = debugLog,
	})

	debugLog("Startup", "Spotlights plugin initialized successfully")
end

startup()
