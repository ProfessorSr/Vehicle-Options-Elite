 
-- V O E   P L U G I N S • Hood
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles hood opening/closing with hinge constraints
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
	warn("[Hood] Plugin disabled via config")
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
		-- Wait for VOE_State folder to be created (up to 5 seconds)
		local voeState = vehicle:FindFirstChild("VOE_State")
		if not voeState then
			voeState = vehicle:WaitForChild("VOE_State", 5)
		end
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
	print(string.format("[Hood][%s] %s", category, message))
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
	value:SetAttribute("VOE_Owner", "Hood")
	value:SetAttribute("VOE_Type", "State")
	if className == "BoolValue" then value.Value = defaultValue or false
	elseif className == "IntValue" then value.Value = defaultValue or 0 end
	return value
end

local function initializeStateValues()
	if not StateContainer then return end
	StateValues.Hood = ensureStateValue(StateContainer, "Hood", "BoolValue", false)
	-- HoodUnlocked is created by HoodHandler, but we need to reference it
	-- Wait for it to be created if it doesn't exist yet
	local existingUnlocked = StateContainer:FindFirstChild("HoodUnlocked")
	if existingUnlocked then
		StateValues.HoodUnlocked = existingUnlocked
	else
		-- Create it if HoodHandler hasn't run yet (shouldn't happen, but just in case)
		StateValues.HoodUnlocked = ensureStateValue(StateContainer, "HoodUnlocked", "BoolValue", false)
	end
end

--====================================================================
-- Hinge Functions
--====================================================================

local function findHinge(part)
	-- Look for hinge created by VOE_RigBootstrap
	-- Hinge is named "VOE_Hinge_VOE_<Role>" where Role is from the tag
	local hingeName = "VOE_Hinge_VOE_" .. Tags.Role
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

local function setupHinges()
	if not Vehicle then return end
	
	local roots = collectTaggedParts(Tags.Required.Root)
	local parts = collectTaggedParts(Tags.Required.Part)
	Items = {}
	
	debugLog("Setup", "Config OpenAngle: " .. tostring(Config.OpenAngle) .. ", CloseAngle: " .. tostring(Config.CloseAngle))
	debugLog("Setup", "Found " .. #roots .. " root parts")
	
	for _, rootPart in ipairs(roots) do
		local allParts = {rootPart}
		for _, part in ipairs(parts) do
			if part ~= rootPart then
				table.insert(allParts, part)
			end
		end
		
		-- Find existing hinge created by VOE_RigBootstrap
		local hinge = findHinge(rootPart)
		if hinge then
			hinge.AngularSpeed = tonumber(rootPart:GetAttribute(Tags.Optional.OpenSpeedAttribute)) or tonumber(Config.OpenSpeed) or 3.0
			hinge.ServoMaxTorque = tonumber(rootPart:GetAttribute(Tags.Optional.OpenTorqueAttribute)) or tonumber(Config.OpenTorque) or 20000
			hinge.TargetAngle = tonumber(Config.CloseAngle) or 0
			
			local openAngle = tonumber(rootPart:GetAttribute(Tags.Optional.OpenAngleAttribute)) or tonumber(Config.OpenAngle) or 55
			local closeAngle = tonumber(rootPart:GetAttribute("VOE_CloseAngle")) or tonumber(Config.CloseAngle) or 0
			
			debugLog("Setup", "Part: " .. rootPart.Name .. ", OpenAngle: " .. tostring(openAngle) .. ", CloseAngle: " .. tostring(closeAngle))
			
			table.insert(Items, {
				Part = rootPart,
				Hinge = hinge,
				OpenAngle = openAngle,
				CloseAngle = closeAngle,
			})
		else
			debugLog("Setup", "WARNING: No hinge found for part: " .. rootPart.Name)
		end
	end
end

--====================================================================
-- Actions
--====================================================================

local function setOpen(isOpen)
	for _, item in ipairs(Items) do
		if item.Hinge and item.Hinge.Parent and item.Part and item.Part.Parent then
			local targetAngle = isOpen and item.OpenAngle or item.CloseAngle
			debugLog("Action", "Setting TargetAngle to: " .. tostring(targetAngle) .. " (isOpen: " .. tostring(isOpen) .. ")")
			item.Hinge.TargetAngle = targetAngle
		end
	end
end

local function toggle()
	if StateValues.Hood then
		StateValues.Hood.Value = not StateValues.Hood.Value
	end
end

local function applyVisuals()
	if StateValues.Hood then
		setOpen(StateValues.Hood.Value)
	end
end

--====================================================================
-- Keybind Handling
--====================================================================

local function handleKeybind(input, gameProcessed)
	if gameProcessed then return end
	local keyCode = input.KeyCode
	local keybinds = Config.Keybinds or {}
	
	-- Toggle hood (H key)
	if keyCode == (keybinds.ToggleHood or Enum.KeyCode.H) then
		toggle()
		if DEBUG_CONFIG.LogKeybinds ~= false then
			debugLog("Input", "Hood " .. (StateValues.Hood and StateValues.Hood.Value and "ON" or "OFF"))
		end
	end
	
	-- Unlock hood (U key) - like pulling the hood release lever inside the car
	if keyCode == (keybinds.UnlockHood or Enum.KeyCode.U) then
		if StateValues.HoodUnlocked then
			StateValues.HoodUnlocked.Value = true
			if DEBUG_CONFIG.LogKeybinds ~= false then
				debugLog("Input", "Hood UNLOCKED - you can now open it from outside")
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
		warn("[Hood] Could not find vehicle model")
		return
	end
	
	initializeStateValues()
	setupHinges()
	
	if UserInputService then
		UserInputService.InputBegan:Connect(handleKeybind)
	end
	
	if StateValues.Hood then
		StateValues.Hood.Changed:Connect(function()
			applyVisuals()
		end)
	end
	
	applyVisuals()
	debugLog("Startup", "Hood plugin initialized successfully")
end

startup()