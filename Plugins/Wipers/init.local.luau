 
-- V O E   P L U G I N S • Wipers
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles windshield wipers with hinge constraints and sweeping motion
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
	warn("[Wipers] Plugin disabled via config")
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
local ACTION_ORDER = {"ToggleWipers", "ToggleRearWiper", "ToggleHeadlightWipers"}
local ALL_ROLES = {"WiperLeft", "WiperRight", "RearWiper", "HeadlightWiperLeft", "HeadlightWiperRight"}

--====================================================================
-- State Management
--====================================================================

local Vehicle = nil
local StateValues = {}
local StateContainer = nil
local ActionState = {}
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
	print(string.format("[Wipers][%s] %s", category, message))
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
	value:SetAttribute("VOE_Owner", "Wipers")
	value:SetAttribute("VOE_Type", "State")
	if className == "BoolValue" then value.Value = defaultValue or false
	elseif className == "IntValue" then value.Value = defaultValue or 0 end
	return value
end

local function initializeStateValues()
	if not StateContainer then return end
	for actionName, stateName in pairs(Config.StateValues or {}) do
		StateValues[stateName] = ensureStateValue(StateContainer, stateName, "BoolValue", false)
		ActionState[actionName] = {
			StateValue = StateValues[stateName],
			SweepPhase = false,
			Elapsed = 0,
		}
	end
end

--====================================================================
-- Hinge Functions
--====================================================================

local function findHinge(part, roleName)
	local byName = part:FindFirstChild("VOE_AutoHinge_" .. roleName)
	if byName and byName:IsA("HingeConstraint") then
		return byName
	end
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("HingeConstraint") then
			return child
		end
	end
	return nil
end

local function ensureHinge(rootPart, roleName, seat)
	local existing = findHinge(rootPart, roleName)
	if existing then
		return existing
	end
	
	local pivot = rootPart:FindFirstChild(Tags.Optional.HingePivotAttachment)
	local pivotPos = (pivot and pivot:IsA("Attachment")) and pivot.WorldPosition or rootPart.Position
	local pivotAxis = (pivot and pivot:IsA("Attachment")) and pivot.WorldAxis or rootPart.CFrame.UpVector
	
	local a0 = Instance.new("Attachment")
	a0.Name = "VOE_HingeAnchor_" .. roleName
	a0.Parent = seat
	a0.WorldPosition = pivotPos
	a0.WorldAxis = pivotAxis
	
	local a1 = Instance.new("Attachment")
	a1.Name = "VOE_HingeRoot_" .. roleName
	a1.Parent = rootPart
	a1.WorldPosition = pivotPos
	a1.WorldAxis = pivotAxis
	
	local hinge = Instance.new("HingeConstraint")
	hinge.Name = "VOE_AutoHinge_" .. roleName
	hinge.Attachment0 = a0
	hinge.Attachment1 = a1
	hinge.ActuatorType = Enum.ActuatorType.Servo
	hinge.Parent = rootPart
	return hinge
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
	local rootTag = Tags.Required["Wipers_" .. roleName .. "_Root"]
	local partTag = Tags.Required["Wipers_" .. roleName .. "_Part"]
	if not rootTag then return end
	
	local roleConfig = Config.Openables[roleName] or {}
	local roots = collectTaggedParts(rootTag)
	local parts = collectTaggedParts(partTag)
	
	Items[roleName] = {}
	
	local seat = Vehicle and Vehicle:FindFirstChild("DriveSeat")
	if not seat then return end
	
	for _, rootPart in ipairs(roots) do
		local allParts = {rootPart}
		for _, part in ipairs(parts) do
			if part ~= rootPart then
				table.insert(allParts, part)
			end
		end
		
		-- Weld parts to root
		for _, part in ipairs(allParts) do
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
					weld.Name = "VOE_" .. roleName .. "Weld"
					weld.Part0 = rootPart
					weld.Part1 = part
					weld.Parent = part
				end
			end
		end
		
		local hinge = ensureHinge(rootPart, roleName, seat)
		hinge.AngularSpeed = tonumber(rootPart:GetAttribute(Tags.Optional.OpenSpeedAttribute)) or tonumber(roleConfig.OpenSpeed) or 8.0
		hinge.ServoMaxTorque = tonumber(rootPart:GetAttribute(Tags.Optional.OpenTorqueAttribute)) or tonumber(roleConfig.OpenTorque) or 12000
		hinge.TargetAngle = tonumber(roleConfig.MinAngle) or 0
		
		table.insert(Items[roleName], {
			Part = rootPart,
			Hinge = hinge,
			MinAngle = tonumber(rootPart:GetAttribute(Tags.Optional.MinAngleAttribute)) or tonumber(roleConfig.MinAngle) or 0,
			MaxAngle = tonumber(rootPart:GetAttribute(Tags.Optional.MaxAngleAttribute)) or tonumber(roleConfig.MaxAngle) or 60,
		})
	end
end

local function setupAllRoles()
	for _, roleName in ipairs(ALL_ROLES) do
		setupRole(roleName)
	end
end

--====================================================================
-- Actions
--====================================================================

local function setTarget(roleName, sweepOut)
	for _, item in ipairs(Items[roleName] or {}) do
		if item.Hinge and item.Hinge.Parent and item.Part and item.Part.Parent then
			item.Hinge.TargetAngle = sweepOut and item.MaxAngle or item.MinAngle
		end
	end
end

local function setActionParked(actionName)
	local actionState = ActionState[actionName]
	if not actionState then return end
	actionState.SweepPhase = false
	actionState.Elapsed = 0
	for _, roleName in ipairs(Config.Actions[actionName] or {}) do
		setTarget(roleName, false)
	end
end

local function toggleAction(actionName)
	local actionState = ActionState[actionName]
	if not actionState then return false end
	actionState.StateValue.Value = not actionState.StateValue.Value
	if not actionState.StateValue.Value then
		setActionParked(actionName)
	end
	return true
end

--====================================================================
-- Update Loop
--====================================================================

local stepTime = math.max(0.05, tonumber(Config.StepTime) or 0.4)

local function update(dt)
	for _, actionName in ipairs(ACTION_ORDER) do
		local actionState = ActionState[actionName]
		if actionState and actionState.StateValue.Value then
			actionState.Elapsed = actionState.Elapsed + (tonumber(dt) or 0)
			if actionState.Elapsed >= stepTime then
				actionState.Elapsed = 0
				actionState.SweepPhase = not actionState.SweepPhase
				for _, roleName in ipairs(Config.Actions[actionName] or {}) do
					setTarget(roleName, actionState.SweepPhase)
				end
			end
		end
	end
end

--====================================================================
-- Keybind Handling
--====================================================================

local function handleKeybind(input, gameProcessed)
	if gameProcessed then return end
	local keyCode = input.KeyCode
	local keybinds = Config.Keybinds or {}
	
	for _, actionName in ipairs(ACTION_ORDER) do
		if keyCode == (keybinds[actionName] or Enum.KeyCode.Unknown) then
			toggleAction(actionName)
			if DEBUG_CONFIG.LogKeybinds ~= false then
				debugLog("Input", actionName .. " toggled")
			end
			return
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
		warn("[Wipers] Could not find vehicle model")
		return
	end
	
	initializeStateValues()
	setupAllRoles()
	
	-- Connect state change listeners
	for actionName, stateName in pairs(Config.StateValues or {}) do
		if StateValues[stateName] then
			StateValues[stateName].Changed:Connect(function()
				if not StateValues[stateName].Value then
					setActionParked(actionName)
				end
			end)
		end
	end
	
	if UserInputService then
		UserInputService.InputBegan:Connect(handleKeybind)
	end
	
	-- Start update loop
	RunService.Heartbeat:Connect(update)
	
	debugLog("Startup", "Wipers plugin initialized successfully")
end

startup()