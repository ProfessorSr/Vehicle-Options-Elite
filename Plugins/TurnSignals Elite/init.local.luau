 
-- V O E   P L U G I N S • TurnSignals
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles turn signal state, mapping, blinking, and keybinds
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)

-- - Clean, modular, no deprecated code

--====================================================================
-- Module Requires
--====================================================================

local PluginSounds = require(script:WaitForChild("Sounds"))
local Config = require(script:WaitForChild("Config"))
local Tags = require(script:WaitForChild("Tags"))
local Sounds = require(script:WaitForChild("Sounds"))

if Config and Config.Enabled == false then
	warn("[TurnSignals] Plugin disabled via config")
	return
end

--====================================================================
-- Services
--====================================================================

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local UserInputService = RunService:IsClient() and game:GetService("UserInputService") or nil

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

local DEBUG_CONFIG = Config.Debug or {}
local BLINK_INTERVAL = Config.BlinkInterval or 0.5
local ATTACHMENT_YAW_OVERRIDES = Config.AttachmentYawOverrides or {}

local STATE_DEFS = {
	SignalLeft = { ClassName = "BoolValue", Default = false },
	SignalRight = { ClassName = "BoolValue", Default = false },
	Hazard = { ClassName = "BoolValue", Default = false },
	IndicatorPulse = { ClassName = "BoolValue", Default = false },
}

--====================================================================
-- State Management
--====================================================================

local Vehicle = nil
local StateValues = {}
local MappedLights = {}
local StateContainer = nil
local IndicatorPhase = false
local IndicatorTimer = 0

--====================================================================
-- Helper Functions
--====================================================================

local function setupPluginSounds(vehicle)
	local soundsModule = PluginSounds
	if not soundsModule or not soundsModule.setupSounds then return end
	if not vehicle then return end
	local body = vehicle:FindFirstChild("Body")
	if not body then
		body = vehicle:WaitForChild("Body", 10)
	end
	if not body then
		return
	end
	local soundParent = body:FindFirstChild("Sounds")
	if not soundParent then
		soundParent = body:WaitForChild("Sounds", 10)
	end
	if not soundParent then
		soundParent = Instance.new("Folder")
		soundParent.Name = "Sounds"
		soundParent.Parent = body
	end
	soundsModule.setupSounds(soundParent)
end

local function bootstrapPluginSounds()
	local carValue = script.Parent:FindFirstChild("Car")
	if not carValue or not carValue:IsA("ObjectValue") then
		return
	end
	local function apply()
		local vehicle = carValue.Value
		if vehicle and vehicle:IsA("Model") then
			setupPluginSounds(vehicle)
		end
	end
	apply()
	carValue.Changed:Connect(apply)
end

bootstrapPluginSounds()

local function debugLog(category, message)
	if not DEBUG_CONFIG.Enabled then return end
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
	if existing then
		return existing
	end
	local value = Instance.new(className)
	value.Name = name
	value.Parent = values
	-- V O E   P L U G I N S: Standard state attributes
	value:SetAttribute("VOE_Owner", "TurnSignals")
	value:SetAttribute("VOE_Type", "State")
	if className == "IntValue" then
		value.Value = defaultValue or 0
	elseif className == "BoolValue" then
		value.Value = defaultValue or false
	elseif className == "StringValue" then
		value.Value = defaultValue or "" 
	end
	return value
end

local function initializeStateValues()
	if not StateContainer then return end
	for stateName, spec in pairs(STATE_DEFS) do
		StateValues[stateName] = ensureStateValue(StateContainer, stateName, spec.ClassName, spec.Default)
	end
end

--====================================================================
-- Light Mapping Functions
--====================================================================

local function resolveBasePart(inst)
	if inst:IsA("BasePart") then
		return inst
	elseif inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart")
	elseif inst:IsA("Attachment") then
		return inst.Parent
	elseif inst:IsA("Light") then
		local parent = inst.Parent
		if parent and parent:IsA("Attachment") then
			return parent.Parent
		end
		return parent
	end
	return nil
end

local function ensureSpotlight(part, profile, profileName)
	local attachmentName
	if profileName == "SignalLeftRear" or profileName == "SignalRightRear" then
		attachmentName = "VOE_LightAttachment_SignalRear"
	else
		attachmentName = "VOE_LightAttachment"
	end
	local attachment = part:FindFirstChild(attachmentName)
	if not attachment or not attachment:IsA("Attachment") then
		attachment = Instance.new("Attachment")
		attachment.Name = attachmentName
		attachment.Parent = part
	end
	local defaultYaw = 0
	if profileName == "SignalLeftRear" or profileName == "SignalRightRear" then
		defaultYaw = 180
	end
	local yawDegrees = ATTACHMENT_YAW_OVERRIDES[profileName]
	if yawDegrees == nil then
		yawDegrees = defaultYaw
	end
	attachment.CFrame = CFrame.Angles(0, math.rad(yawDegrees), 0)
	local spot = attachment:FindFirstChild("VOE_SpotLight")
	if not spot or not spot:IsA("SpotLight") then
		if spot then spot:Destroy() end
		spot = Instance.new("SpotLight")
		spot.Name = "VOE_SpotLight"
		spot.Parent = attachment
	end
	spot.Brightness = Config.Lights.Signal.Brightness or 1
	spot.Range = Config.Lights.Signal.Range or 24
	spot.Angle = Config.Lights.Signal.Angle or 80
	spot.Color = Config.Lights.Signal.Color or Color3.fromRGB(255, 170, 0)
	spot.Shadows = Config.Lights.Signal.Shadows ~= false
	spot.Enabled = false
	return spot
end

local function mapLightsByTag(tagName, profileName)
	if not tagName or tagName == "" then return {} end
	local list = {}
	for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
		local part = resolveBasePart(inst)
		if part and Vehicle and part:IsDescendantOf(Vehicle) then
			local spot = ensureSpotlight(part, Config.Lights.Signal, profileName)
			table.insert(list, {
				Spot = spot,
				Part = part,
				Profile = Config.Lights.Signal,
				OrigMaterial = part.Material,
				OrigColor = part.Color,
			})
		end
	end
	return list
end

local function setupLightMapping()
	if not Vehicle then return end
	MappedLights = {
		SignalLeft = {
			Main = mapLightsByTag(Tags.Required.SignalLeft_Tag, "SignalLeft"),
			Front = mapLightsByTag(Tags.Required.SignalLeftFront_Tag, "SignalLeftFront"),
			Rear = mapLightsByTag(Tags.Required.SignalLeftRear_Tag, "SignalLeftRear"),
			Side = mapLightsByTag(Tags.Required.SignalLeftSide_Tag, "SignalLeftSide"),
		},
		SignalRight = {
			Main = mapLightsByTag(Tags.Required.SignalRight_Tag, "SignalRight"),
			Front = mapLightsByTag(Tags.Required.SignalRightFront_Tag, "SignalRightFront"),
			Rear = mapLightsByTag(Tags.Required.SignalRightRear_Tag, "SignalRightRear"),
			Side = mapLightsByTag(Tags.Required.SignalRightSide_Tag, "SignalRightSide"),
		},
	}
end

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

local function applySignalState()
	local leftActive = StateValues.Hazard.Value or StateValues.SignalLeft.Value
	local rightActive = StateValues.Hazard.Value or StateValues.SignalRight.Value
	local signalPhase = (leftActive or rightActive) and IndicatorPhase or false

	-- Left signals
	if leftActive then
		if signalPhase then
			enableLights(MappedLights.SignalLeft.Main)
			enableLights(MappedLights.SignalLeft.Front)
			enableLights(MappedLights.SignalLeft.Rear)
			enableLights(MappedLights.SignalLeft.Side)
		else
			disableLights(MappedLights.SignalLeft.Main)
			disableLights(MappedLights.SignalLeft.Front)
			disableLights(MappedLights.SignalLeft.Rear)
			disableLights(MappedLights.SignalLeft.Side)
		end
	else
		disableLights(MappedLights.SignalLeft.Main)
		disableLights(MappedLights.SignalLeft.Front)
		disableLights(MappedLights.SignalLeft.Rear)
		disableLights(MappedLights.SignalLeft.Side)
	end

	-- Right signals
	if rightActive then
		if signalPhase then
			enableLights(MappedLights.SignalRight.Main)
			enableLights(MappedLights.SignalRight.Front)
			enableLights(MappedLights.SignalRight.Rear)
			enableLights(MappedLights.SignalRight.Side)
		else
			disableLights(MappedLights.SignalRight.Main)
			disableLights(MappedLights.SignalRight.Front)
			disableLights(MappedLights.SignalRight.Rear)
			disableLights(MappedLights.SignalRight.Side)
		end
	else
		disableLights(MappedLights.SignalRight.Main)
		disableLights(MappedLights.SignalRight.Front)
		disableLights(MappedLights.SignalRight.Rear)
		disableLights(MappedLights.SignalRight.Side)
	end
end

local function handleKeybind(input, gameProcessed)
	if gameProcessed then return end
	local keyCode = input.KeyCode
	local keybinds = Config.Keybinds or {}
	if keyCode == (keybinds.ToggleSignalLeft or Enum.KeyCode.Z) then
		StateValues.SignalLeft.Value = not StateValues.SignalLeft.Value
		StateValues.SignalRight.Value = false
		StateValues.Hazard.Value = false
		debugLog("Input", "SignalLeft toggled")
	elseif keyCode == (keybinds.ToggleSignalRight or Enum.KeyCode.X) then
		StateValues.SignalRight.Value = not StateValues.SignalRight.Value
		StateValues.SignalLeft.Value = false
		StateValues.Hazard.Value = false
		debugLog("Input", "SignalRight toggled")
	elseif keyCode == (keybinds.ToggleHazard or Enum.KeyCode.C) then
		StateValues.Hazard.Value = not StateValues.Hazard.Value
		StateValues.SignalLeft.Value = false
		StateValues.SignalRight.Value = false
		debugLog("Input", "Hazard toggled")
	end
end

local function updateHeartbeat(dt)
	IndicatorTimer = IndicatorTimer + dt
	if IndicatorTimer >= BLINK_INTERVAL then
		IndicatorTimer = 0
		IndicatorPhase = not IndicatorPhase
		if StateValues.IndicatorPulse then
			StateValues.IndicatorPulse.Value = IndicatorPhase
		end
		applySignalState()
		-- Play tick sound if any signal is active
		local leftActive = StateValues.Hazard.Value or StateValues.SignalLeft.Value
		local rightActive = StateValues.Hazard.Value or StateValues.SignalRight.Value
		if leftActive or rightActive then
			local soundDef = Sounds.Indicator
			if soundDef and soundDef.SoundId then
				local sound = Instance.new("Sound")
				sound.SoundId = "rbxassetid://" .. tostring(soundDef.SoundId)
				sound.Volume = soundDef.Volume or 0.45
				sound.Parent = workspace
				sound:Play()
				sound.Ended:Connect(function()
					sound:Destroy()
				end)
			end
		end
	end
end

local function startup()
	local runtimeCar, runtimeValues = findRuntimeCarAndValues()
	if not runtimeCar then
		warn("[TurnSignals] Could not find vehicle model")
		return

	end
	Vehicle = runtimeCar
	StateContainer = runtimeValues or Vehicle
	setupPluginSounds(Vehicle)
	if not StateContainer then
		warn("[TurnSignals] Could not resolve state container")
		return
	end
	initializeStateValues()
	setupLightMapping()
	if UserInputService then
		UserInputService.InputBegan:Connect(handleKeybind)
	end
	for _, stateValue in pairs(StateValues) do
		if stateValue then
			stateValue.Changed:Connect(function()
				applySignalState()
			end)
		end
	end
	RunService.Heartbeat:Connect(updateHeartbeat)
	applySignalState()
	end

startup()
