 
-- V O E   P L U G I N S • Popups
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles popup headlights with hinge constraints
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)

-- - Clean, modular, no deprecated code

--====================================================================
-- Module Requires
--====================================================================

local Config = require(script:WaitForChild("Config"))
local Tags = require(script:WaitForChild("Tags"))
local PluginSounds = require(script:WaitForChild("Sounds"))

if Config and Config.Enabled == false then
	warn("[Popups] Plugin disabled via config")
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
local ROLE_ORDER = {"PopupLeft", "PopupRight"}

--====================================================================
-- State Management
--====================================================================

local Vehicle = nil
local StateValues = {}
local StateContainer = nil
local Items = {}

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
	print(string.format("[Popups][%s] %s", category, message))
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
	value:SetAttribute("VOE_Owner", "Popups")
	value:SetAttribute("VOE_Type", "State")
	if className == "BoolValue" then value.Value = defaultValue or false
	elseif className == "IntValue" then value.Value = defaultValue or 0 end
	return value
end

local function initializeStateValues()
	if not StateContainer then return end
	StateValues.Popups = ensureStateValue(StateContainer, "Popups", "BoolValue", false)
end

--====================================================================
-- Hinge Functions
--====================================================================

local function findHinge(part, roleName)
	-- Look for hinge created by VOE_RigBootstrap
	local hingeName = "VOE_Hinge_VOE_" .. roleName
	local byName = part:FindFirstChild(hingeName)
	if byName and byName:IsA("HingeConstraint") then
		return byName
	end
	-- Fallback: look for any HingeConstraint on the part
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("HingeConstraint") then
			return child
		end
	end
	return nil
end

--====================================================================
-- Tag Collection
--====================================================================

local function collectTaggedParts(tagName)
	local out = {}
	if type(tagName) ~= "string" or tagName == "" then
		return out
	end
	for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
		if inst:IsA("BasePart") then
			table.insert(out, inst)
		end
	end
	return out
end

--====================================================================
-- Setup
--====================================================================

local function setupRole(roleName)
	local rootTag = Tags.Required["Popups_" .. roleName .. "_Root"]
	local partTag = Tags.Required["Popups_" .. roleName .. "_Part"]
	if not rootTag then return end
	
	local roleConfig = Config.Openables[roleName] or {}
	local roots = collectTaggedParts(rootTag)
	local parts = collectTaggedParts(partTag)
	
	Items[roleName] = {}
	
	for _, rootPart in ipairs(roots) do
		-- Find existing hinge created by VOE_RigBootstrap
		local hinge = findHinge(rootPart, roleName)
		if hinge then
			hinge.AngularSpeed = tonumber(rootPart:GetAttribute(Tags.Optional.OpenSpeedAttribute)) or tonumber(roleConfig.OpenSpeed) or 3.0
			hinge.ServoMaxTorque = tonumber(rootPart:GetAttribute(Tags.Optional.OpenTorqueAttribute)) or tonumber(roleConfig.OpenTorque) or 20000
			hinge.TargetAngle = tonumber(roleConfig.CloseAngle) or 0
			
			table.insert(Items[roleName], {
				Part = rootPart,
				Hinge = hinge,
				OpenAngle = tonumber(rootPart:GetAttribute(Tags.Optional.OpenAngleAttribute)) or tonumber(roleConfig.OpenAngle) or 45,
				CloseAngle = tonumber(rootPart:GetAttribute("VOE_CloseAngle")) or tonumber(roleConfig.CloseAngle) or 0,
			})
		end
	end
end

local function setupAllRoles()
	for _, roleName in ipairs(ROLE_ORDER) do
		setupRole(roleName)
	end
end

--====================================================================
-- Actions
--====================================================================

local function setRoleOpen(roleName, isOpen)
	for _, item in ipairs(Items[roleName] or {}) do
		if item.Hinge and item.Hinge.Parent and item.Part and item.Part.Parent then
			item.Hinge.TargetAngle = isOpen and item.OpenAngle or item.CloseAngle
		end
	end
end

local function toggle()
	if StateValues.Popups then
		StateValues.Popups.Value = not StateValues.Popups.Value
	end
end

local function applyVisuals()
	local isOpen = StateValues.Popups and StateValues.Popups.Value or false
	
	-- AutoOnHeadlights: if headlights are on, popups should be up regardless of toggle state
	if Config.AutoOnHeadlights then
		local headlightMode = StateContainer and StateContainer:FindFirstChild("HeadlightMode")
		if headlightMode and headlightMode:IsA("IntValue") and headlightMode.Value > 0 then
			isOpen = true
		end
	end
	
	for _, roleName in ipairs(ROLE_ORDER) do
		setRoleOpen(roleName, isOpen)
	end
end

--====================================================================
-- Keybind Handling
--====================================================================

local function handleKeybind(input, gameProcessed)
	if gameProcessed then return end
	local keyCode = input.KeyCode
	local keybinds = Config.Keybinds or {}
	if keyCode == (keybinds.TogglePopups or Enum.KeyCode.P) then
		toggle()
		if DEBUG_CONFIG.LogKeybinds ~= false then
			debugLog("Input", "Popups " .. (StateValues.Popups and StateValues.Popups.Value and "ON" or "OFF"))
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
		warn("[Popups] Could not find vehicle model")
		return
	end
	
	initializeStateValues()
	setupAllRoles()
	
	if StateValues.Popups then
		StateValues.Popups.Changed:Connect(function()
			applyVisuals()
		end)
	end
	
	-- Watch headlight mode for AutoOnHeadlights
	if Config.AutoOnHeadlights and StateContainer then
		local headlightMode = StateContainer:FindFirstChild("HeadlightMode")
		if headlightMode and headlightMode:IsA("IntValue") then
			headlightMode.Changed:Connect(function()
				applyVisuals()
			end)
		end
	end
	
	if UserInputService then
		UserInputService.InputBegan:Connect(handleKeybind)
	end
	
	applyVisuals()
	debugLog("Startup", "Popups plugin initialized successfully")
end

startup()