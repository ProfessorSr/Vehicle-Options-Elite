 
-- V O E   P L U G I N S • Doors
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles door state and keybinds
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)

-- - Hinges are created by VOE_RigBootstrap

--====================================================================
-- Module Requires
--====================================================================

local Config = require(script:WaitForChild("Config"))
local Tags = require(script:WaitForChild("Tags"))
local PluginSounds = require(script:WaitForChild("Sounds"))

if Config and Config.Enabled == false then
	warn("[Doors] Plugin disabled via config")
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
local ROLE_ORDER = {"DoorFL", "DoorFR", "DoorRL", "DoorRR", "DoorSL", "DoorSR", "GasDoor"}

--====================================================================
-- State Management
--====================================================================

local Vehicle = nil
local StateValues = {}
local StateContainer = nil
local LastToggleAt = {}
local Items = {} -- Stores {Part, Hinge, OpenAngle, CloseAngle} for each role

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
		if not voeState then
			voeState = vehicle:FindFirstChild("VOE_State") or vehicle:WaitForChild("VOE_State", 5)
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
	print(string.format("[Doors][%s] %s", category, message))
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
	value:SetAttribute("VOE_Owner", "Doors")
	value:SetAttribute("VOE_Type", "State")
	if className == "BoolValue" then value.Value = defaultValue or false
	elseif className == "IntValue" then value.Value = defaultValue or 0 end
	return value
end

local function initializeStateValues()
	if not StateContainer then return end
	for _, roleName in ipairs(ROLE_ORDER) do
		StateValues[roleName] = ensureStateValue(StateContainer, roleName, "BoolValue", false)
	end
	StateValues.DoorLocked = ensureStateValue(StateContainer, "DoorLocked", "BoolValue", false)
end

--====================================================================
-- Hinge Setup (finds hinges created by VOE_RigBootstrap)
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

local function getRoleConfig(roleName)
	return Config.Presets[roleName] or {}
end

local function setupRole(roleName)
	local rootTag = Tags.Required["Doors_" .. roleName .. "_Root"]
	if not rootTag then return end
	
	local roleConfig = getRoleConfig(roleName)
	local roots = collectTaggedParts(rootTag)
	
	Items[roleName] = {}
	
	for _, rootPart in ipairs(roots) do
		-- Find the hinge created by VOE_RigBootstrap
		-- Hinge is named "VOE_Hinge_VOE_<RoleName>" and parented to the part
		local hingeName = "VOE_Hinge_VOE_" .. roleName
		local hinge = rootPart:FindFirstChild(hingeName)
		
		if not hinge or not hinge:IsA("HingeConstraint") then
			-- Fallback: find any HingeConstraint
			for _, child in ipairs(rootPart:GetChildren()) do
				if child:IsA("HingeConstraint") then
					hinge = child
					break
				end
			end
		end
		
		if hinge then
			debugLog("Hinge", string.format("Found hinge '%s' on %s (A0=%s, A1=%s, Target=%.2f)",
					(hinge.Name or "<unnamed>"), rootPart:GetFullName(),
					(hinge.Attachment0 and hinge.Attachment0.Name) or "<nil>",
					(hinge.Attachment1 and hinge.Attachment1.Name) or "<nil>",
					type(hinge.TargetAngle) == "number" and hinge.TargetAngle or 0))

			-- Extra diagnostics: attachment world CFrames
			if hinge.Attachment0 then
				debugLog("Hinge", string.format("A0 WorldCF=%s", tostring(hinge.Attachment0.WorldCFrame)))
			end
			if hinge.Attachment1 then
				debugLog("Hinge", string.format("A1 WorldCF=%s", tostring(hinge.Attachment1.WorldCFrame)))
			end

			-- List any welds or weldconstraints on the root part that may block motion
			for _, c in ipairs(rootPart:GetChildren()) do
				if c:IsA("Weld") or c:IsA("WeldConstraint") or c:IsA("Motor6D") then
					local p0 = c.Part0 and c.Part0.Name or "<nil>"
					local p1 = c.Part1 and c.Part1.Name or "<nil>"
					debugLog("Hinge", string.format("Root has %s -> Part0=%s Part1=%s", c.ClassName, p0, p1))
				end
			end

			-- Get angles from config or part attributes
			local openAngle = tonumber(rootPart:GetAttribute(Tags.Optional.OpenAngleAttribute)) or tonumber(roleConfig.OpenAngle) or 50
			local closeAngle = tonumber(rootPart:GetAttribute("VOE_CloseAngle")) or tonumber(roleConfig.CloseAngle) or 0
			
			-- Apply speed and torque from config
			hinge.AngularSpeed = tonumber(rootPart:GetAttribute(Tags.Optional.OpenSpeedAttribute)) or tonumber(roleConfig.OpenSpeed) or 3.0
			hinge.ServoMaxTorque = tonumber(rootPart:GetAttribute(Tags.Optional.OpenTorqueAttribute)) or tonumber(roleConfig.OpenTorque) or 20000
			
			-- Set initial position to closed
			hinge.TargetAngle = closeAngle
			
			table.insert(Items[roleName], {
				Part = rootPart,
				Hinge = hinge,
				OpenAngle = openAngle,
				CloseAngle = closeAngle,
			})
			
			debugLog("Setup", roleName .. ": OpenAngle=" .. openAngle .. ", CloseAngle=" .. closeAngle)
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
			debugLog("Action", string.format("Set %s TargetAngle=%.2f (open=%s)", roleName, item.Hinge.TargetAngle, tostring(isOpen)))
		end
	end
end

local function applyVisuals()
	for _, roleName in ipairs(ROLE_ORDER) do
		local isOpen = StateValues[roleName] and StateValues[roleName].Value or false
		setRoleOpen(roleName, isOpen)
	end
end

local function toggleRole(roleName)
	local stateValue = StateValues[roleName]
	if not stateValue then return false end
	if StateValues.DoorLocked and StateValues.DoorLocked.Value then return true end
	local debounce = math.max(0, tonumber(Config.ToggleDebounce) or 0.2)
	local now = tick()
	local last = LastToggleAt[roleName]
	if last and (now - last) < debounce then return true end
	LastToggleAt[roleName] = now
	stateValue.Value = not stateValue.Value
	debugLog("Toggle", string.format("%s toggled -> %s", roleName, tostring(stateValue.Value)))
	return true
end

--====================================================================
-- Keybind Handling
--====================================================================

local function handleKeybind(input, gameProcessed)
	if gameProcessed then return end
	local keyCode = input.KeyCode
	local keybinds = Config.Keybinds or {}
	
	local keybindMap = {
		["ToggleDoorFL"] = "DoorFL",
		["ToggleDoorFR"] = "DoorFR",
		["ToggleDoorRL"] = "DoorRL",
		["ToggleDoorRR"] = "DoorRR",
		["ToggleDoorSL"] = "DoorSL",
		["ToggleDoorSR"] = "DoorSR",
		["ToggleGasDoor"] = "GasDoor",
	}
	
	for keybindName, roleName in pairs(keybindMap) do
		if keyCode == (keybinds[keybindName] or Enum.KeyCode.Unknown) then
			toggleRole(roleName)
			if DEBUG_CONFIG.LogKeybinds ~= false then
				debugLog("Input", roleName .. " toggled")
			end
			return
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
		warn("[Doors] Could not find vehicle model")
		return
	end
	
	initializeStateValues()
	setupAllRoles()
	
	-- Connect state change listeners
	for _, roleName in ipairs(ROLE_ORDER) do
		if StateValues[roleName] then
			StateValues[roleName].Changed:Connect(function()
				applyVisuals()
			end)
		end
	end
	
	if UserInputService then
		UserInputService.InputBegan:Connect(handleKeybind)
	end
	
	applyVisuals()
	debugLog("Startup", "Doors plugin initialized successfully")
end

startup()
