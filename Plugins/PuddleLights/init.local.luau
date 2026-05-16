--
-- PPPP    SSSS    11        PPPP   L      U   U   GGGG   III  N   N
-- P   P   S         1        P   P  L      U   U  G        I   NN  N
-- PPPP    SSS      1        PPPP   L      U   U  G  GG    I   N N N
-- P         S      1        P      L      U   U  G   G    I   N  NN
-- P      SSSS     111       P      LLLLL   UUU    GGGG   III  N   N
--
-- V O E   P L U G I N S • PuddleLights
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles door puddle light state - automatic with doors.
-- Each door has its own puddle light that activates independently.
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)
-- - Per-door control: FL/FR/RL/RR each activate independently
-- - Legacy Left/Right tags supported as fallback

--====================================================================
-- Module Requires
--====================================================================

local Config = require(script:WaitForChild("Config"))
local Tags = require(script:WaitForChild("Tags"))

if Config and Config.Enabled == false then
	warn("[PuddleLights] Plugin disabled via config")
	return
end

--====================================================================
-- Services
--====================================================================

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

--====================================================================
-- Configuration
--====================================================================

local DEBUG_CONFIG = Config.Debug or {}
local ROLE_ORDER = {"FL", "FR", "RL", "RR"}

--====================================================================
-- State Management
--====================================================================

local Vehicle = nil
local StateContainer = nil
local MappedLights = {}   -- {FL = {entries}, FR = {entries}, ...} per-door
local LegacyLights = {}   -- {Left = {entries}, Right = {entries}} for legacy tags
local DoorStateValues = {} -- {FL = BoolValue, FR = BoolValue, ...}

--====================================================================
-- Context Resolution
--====================================================================

local function findRuntimeCarAndValues()
	local pluginContainer = script.Parent
	local valuesFolder = pluginContainer:FindFirstChild("Values")

	-- Look for Car ObjectValue in A-Chassis Interface (sibling of Plugins folder)
	local chassisInterface = pluginContainer.Parent and pluginContainer.Parent:FindFirstChild("A-Chassis Interface")
	local carValue = chassisInterface and chassisInterface:FindFirstChild("Car")

	-- Fallback: check pluginContainer directly (legacy)
	if not carValue then
		carValue = pluginContainer:FindFirstChild("Car")
	end

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
-- Helper Functions
--====================================================================

local function debugLog(category, message)
	if not DEBUG_CONFIG.Enabled then return end
	print(string.format("[PuddleLights][%s] %s", category, message))
end

local function findDoorStateValues()
	if not StateContainer then return end
	local values = StateContainer
	if not StateContainer:IsA("Folder") then
		values = StateContainer:FindFirstChild("Values")
	end
	if not values then return end

	for _, doorRole in ipairs(ROLE_ORDER) do
		local name = "Door" .. doorRole
		local stateValue = values:FindFirstChild(name)
		if stateValue and stateValue:IsA("BoolValue") then
			DoorStateValues[doorRole] = stateValue
			debugLog("Init", "Found door state: " .. name)
		end
	end
end

--====================================================================
-- Light Mapping Functions
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
	local attachmentName = "VOE_LightAttachment"
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

	spot.Brightness = profile.Brightness or 1.4
	spot.Range = profile.Range or 18
	spot.Angle = profile.Angle or 95
	spot.Color = profile.Color or Color3.fromRGB(255, 245, 230)
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

	-- Per-door puddle lights (preferred)
	for _, doorRole in ipairs(ROLE_ORDER) do
		local tagKey = "Puddle" .. doorRole .. "_Tag"
		local tagName = Tags.Required[tagKey]
		if tagName then
			local entries = mapLightsByTag(tagName, Config.Lights.Puddle)
			if #entries > 0 then
				MappedLights[doorRole] = entries
				debugLog("Setup", doorRole .. ": " .. #entries .. " puddle light(s) mapped")
			end
		end
	end

	-- Legacy Left/Right tags (fallback)
	local leftTag = Tags.Required.PuddleLeft_Tag
	local rightTag = Tags.Required.PuddleRight_Tag
	if leftTag then
		local entries = mapLightsByTag(leftTag, Config.Lights.Puddle)
		if #entries > 0 then
			LegacyLights.Left = entries
			debugLog("Setup", "Legacy Left: " .. #entries .. " puddle light(s) mapped")
		end
	end
	if rightTag then
		local entries = mapLightsByTag(rightTag, Config.Lights.Puddle)
		if #entries > 0 then
			LegacyLights.Right = entries
			debugLog("Setup", "Legacy Right: " .. #entries .. " puddle light(s) mapped")
		end
	end
end

--====================================================================
-- Light Control
--====================================================================

local function enableLights(lightList)
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

--====================================================================
-- State Logic
--====================================================================

local function applyLightState()
	-- Per-door puddle lights
	for _, doorRole in ipairs(ROLE_ORDER) do
		local doorState = DoorStateValues[doorRole]
		local isOpen = doorState and doorState.Value or false
		local lightList = MappedLights[doorRole]
		if lightList then
			if isOpen then
				enableLights(lightList)
			else
				disableLights(lightList)
			end
		end
	end

	-- Legacy Left/Right puddle lights
	local leftDoorsOpen = (DoorStateValues.FL and DoorStateValues.FL.Value)
		or (DoorStateValues.RL and DoorStateValues.RL.Value)
	if LegacyLights.Left then
		if leftDoorsOpen then
			enableLights(LegacyLights.Left)
		else
			disableLights(LegacyLights.Left)
		end
	end

	local rightDoorsOpen = (DoorStateValues.FR and DoorStateValues.FR.Value)
		or (DoorStateValues.RR and DoorStateValues.RR.Value)
	if LegacyLights.Right then
		if rightDoorsOpen then
			enableLights(LegacyLights.Right)
		else
			disableLights(LegacyLights.Right)
		end
	end
end

--====================================================================
-- Startup
--====================================================================

local function startup()
	local runtimeCar, runtimeValues = findRuntimeCarAndValues()
	Vehicle = runtimeCar
	StateContainer = runtimeValues or Vehicle

	if not Vehicle then
		warn("[PuddleLights] Could not find vehicle model")
		return
	end

	findDoorStateValues()
	setupLightMapping()

	-- Connect to door state changes
	for _, doorRole in ipairs(ROLE_ORDER) do
		local doorState = DoorStateValues[doorRole]
		if doorState then
			doorState.Changed:Connect(applyLightState)
		end
	end

	applyLightState()
	debugLog("Startup", "PuddleLights plugin initialized successfully")
end

startup()