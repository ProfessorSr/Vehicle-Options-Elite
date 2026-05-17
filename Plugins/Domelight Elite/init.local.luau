 
-- V O E   P L U G I N S • Domelight
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles dome light state - automatic with doors AND manual switch
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)
-- - Designed for VOE-Chassis (A-Chassis compatible)
-- - Clean, modular, no deprecated code

--====================================================================
-- Module Requires
--====================================================================

local Config = require(script:WaitForChild("Config"))
local Tags = require(script:WaitForChild("Tags"))
local PluginSounds = require(script:WaitForChild("Sounds"))

if Config and Config.Enabled == false then
	warn("[Domelight] Plugin disabled via config")
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

--====================================================================
-- State Management
--====================================================================

local Vehicle = nil
local StateValues = {}
local StateContainer = nil
local MappedLights = {}
local DoorStateValues = {}

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
	print(string.format("[Domelight][%s] %s", category, message))
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
	value:SetAttribute("VOE_Owner", "Domelight")
	value:SetAttribute("VOE_Type", "State")
	if className == "BoolValue" then value.Value = defaultValue or false end
	return value
end

local function initializeStateValues()
	if not StateContainer then return end
	StateValues.Domelight = ensureStateValue(StateContainer, "Domelight", "BoolValue", false)
end

local function findDoorStateValues()
	if not StateContainer then return end
	local values = StateContainer
	if not StateContainer:IsA("Folder") then
		values = StateContainer:FindFirstChild("Values")
	end
	if not values then return end
	
	for _, name in ipairs({"DoorFL", "DoorFR", "DoorRL", "DoorRR"}) do
		local stateValue = values:FindFirstChild(name)
		if stateValue and stateValue:IsA("BoolValue") then
			DoorStateValues[name] = stateValue
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

local function ensurePointLight(part, profile)
	local lightName = "VOE_DomeLight"
	local light = part:FindFirstChild(lightName)
	if not light or not light:IsA("PointLight") then
		if light then light:Destroy() end
		light = Instance.new("PointLight")
		light.Name = lightName
		light.Parent = part
	end
	light.Brightness = profile.Brightness or 1.2
	light.Range = profile.Range or 25
	light.Color = profile.Color or Color3.fromRGB(255, 245, 220)
	light.Shadows = profile.Shadows ~= false
	light.Enabled = false
	return light
end

local function mapLightsByTag(tagName, profile)
	if not tagName or tagName == "" then return {} end
	local list = {}
	for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
		local part = resolveBasePart(inst)
		if part and Vehicle and part:IsDescendantOf(Vehicle) then
			local light = ensurePointLight(part, profile)
			table.insert(list, {
				Light = light,
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
	MappedLights = mapLightsByTag(Tags.Required.Dome_Tag, Config.Lights.Dome)
end

--====================================================================
-- Light Control
--====================================================================

local function enableLights()
	for _, entry in ipairs(MappedLights) do
		if entry.Light and entry.Light.Parent then
			entry.Light.Enabled = true
			if entry.Part and entry.Profile then
				entry.Part.Material = Enum.Material.Neon
				entry.Part.Color = entry.Profile.Color or entry.Part.Color
			end
		end
	end
end

local function disableLights()
	for _, entry in ipairs(MappedLights) do
		if entry.Light and entry.Light.Parent then
			entry.Light.Enabled = false
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

-- Domelight logic:
-- - If AutoWithDoors is true: light is ON when (any door open) OR (manual switch is ON)
-- - If AutoWithDoors is false: light is ON when manual switch is ON

local function calculateLightState()
	local manualOn = StateValues.Domelight and StateValues.Domelight.Value or false
	
	if not Config.AutoWithDoors then
		return manualOn
	end
	
	-- Check if any door is open
	local anyDoorOpen = false
	for _, stateValue in pairs(DoorStateValues) do
		if stateValue.Value then
			anyDoorOpen = true
			break
		end
	end
	
	return anyDoorOpen or manualOn
end

local function applyLightState()
	if calculateLightState() then
		enableLights()
	else
		disableLights()
	end
end

--====================================================================
-- Keybind Handling
--====================================================================

local function handleKeybind(input, gameProcessed)
	if gameProcessed then return end
	local keyCode = input.KeyCode
	local keybinds = Config.Keybinds or {}
	if keyCode == (keybinds.ToggleDomelight or Enum.KeyCode.L) then
		if StateValues.Domelight then
			StateValues.Domelight.Value = not StateValues.Domelight.Value
			if DEBUG_CONFIG.LogKeybinds ~= false then
				debugLog("Input", "Domelight switch " .. (StateValues.Domelight.Value and "ON" or "OFF"))
			end
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
	setupPluginSounds(Vehicle)
	
	if not Vehicle then
		warn("[Domelight] Could not find vehicle model")
		return
	end
	
	initializeStateValues()
	findDoorStateValues()
	setupLightMapping()
	
	-- Connect to manual switch changes
	if StateValues.Domelight then
		StateValues.Domelight.Changed:Connect(applyLightState)
	end
	
	-- Connect to door state changes
	for name, stateValue in pairs(DoorStateValues) do
		stateValue.Changed:Connect(applyLightState)
	end
	
	if UserInputService then
		UserInputService.InputBegan:Connect(handleKeybind)
	end
	
	applyLightState()
	debugLog("Startup", "Domelight plugin initialized successfully")
end

startup()