 
-- V O E   P L U G I N S • PowerSteps
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles power steps that deploy when doors open.
-- Each door has its own step that deploys/retracts independently.
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)
-- - Per-door deployment: FL/FR/RL/RR each deploy independently
-- - Reads door state from Doors plugin BoolValues
-- - Uses TweenService for smooth deploy/retract animation

--====================================================================
-- Module Requires
--====================================================================

local Config = require(script:WaitForChild("Config"))
local Tags = require(script:WaitForChild("Tags"))
local PluginSounds = require(script:WaitForChild("Sounds"))

if Config and Config.Enabled == false then
	warn("[PowerSteps] Plugin disabled via config")
	return
end

--====================================================================
-- Services
--====================================================================

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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
local DoorStateValues = {} -- {DoorFL = BoolValue, DoorFR = BoolValue, ...}
local Items = {}            -- {FL = {Root, Parts, RetractedCFrame, DeployedCFrame, TweenInfo}, ...}
local ActiveTweens = {}    -- {FL = Tween, ...} tracks in-progress tweens

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
	print(string.format("[PowerSteps][%s] %s", category, message))
end

local function axisVector(axisName)
	local axis = string.upper(tostring(axisName or "Y"))
	if axis == "X" then return Vector3.new(1, 0, 0)
	elseif axis == "Z" then return Vector3.new(0, 0, 1) end
	return Vector3.new(0, 1, 0)
end

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

local function findDoorStateValues(container)
	if not container then return end
	local values = container
	if not container:IsA("Folder") then
		values = container:FindFirstChild("Values")
	end
	if not values then return end

	-- Find door state values created by Doors plugin
	for _, doorRole in ipairs(ROLE_ORDER) do
		local name = "Door" .. doorRole
		local stateValue = values:FindFirstChild(name)
		if stateValue and stateValue:IsA("BoolValue") then
			DoorStateValues[doorRole] = stateValue
		end
	end
end

--====================================================================
-- Part Collection & Setup
--====================================================================

local function getRoleConfig(roleName)
	return Config.Doors[roleName] or {}
end

local function setupRole(roleName)
	local rootTag = Tags.Required["PowerSteps_" .. roleName .. "_Root"]
	local partTag = Tags.Required["PowerSteps_" .. roleName .. "_Part"]
	if not rootTag then return end

	local roleCfg = getRoleConfig(roleName)
	local roots = collectTaggedParts(rootTag)
	if #roots == 0 then
		debugLog("Setup", roleName .. ": No root parts found with tag " .. tostring(rootTag))
		return
	end

	local extraParts = collectTaggedParts(partTag or "")

	-- Use the first root as the primary step part
	local rootPart = roots[1]

	-- Read deployment parameters from part attributes (override config)
	local deployDistance = tonumber(rootPart:GetAttribute(Tags.Optional.DeployDistance))
		or tonumber(roleCfg.DeployDistance) or -1.5
	local deployAngleDeg = tonumber(rootPart:GetAttribute(Tags.Optional.DeployAngle))
		or tonumber(roleCfg.DeployAngle) or 0
	local deployAxis = rootPart:GetAttribute(Tags.Optional.DeployAxis)
		or roleCfg.DeployAxis or "Y"
	local tweenTime = tonumber(roleCfg.TweenTime) or 0.22

	-- Store the retracted (current) CFrame of the root
	local retractedCFrame = rootPart.CFrame

	-- Calculate the deployed CFrame by offsetting along the deploy axis
	local axisDir = axisVector(deployAxis)
	-- Transform axis into object space so the step moves relative to its own orientation
	local objectAxis = retractedCFrame:VectorToWorldSpace(axisDir)
	local positionOffset = objectAxis * deployDistance

	-- Apply rotation if DeployAngle is nonzero
	local rotationOffset = CFrame.Angles(
		deployAxis == "X" and math.rad(deployAngleDeg) or 0,
		deployAxis == "Y" and math.rad(deployAngleDeg) or 0,
		deployAxis == "Z" and math.rad(deployAngleDeg) or 0
	)
	local deployedCFrame = retractedCFrame * rotationOffset + positionOffset

	-- Ensure all step parts are anchored (they move via CFrame tween, not physics)
	rootPart.Anchored = true
	for _, part in ipairs(extraParts) do
		part.Anchored = true
	end

	Items[roleName] = {
		Root = rootPart,
		Parts = extraParts,
		RetractedCFrame = retractedCFrame,
		DeployedCFrame = deployedCFrame,
		TweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	}

	debugLog("Setup", roleName .. ": Root=" .. rootPart.Name
		.. ", DeployDistance=" .. tostring(deployDistance)
		.. ", DeployAxis=" .. deployAxis
		.. ", TweenTime=" .. tostring(tweenTime))
end

local function setupAllRoles()
	for _, roleName in ipairs(ROLE_ORDER) do
		setupRole(roleName)
	end
end

--====================================================================
-- Actions
--====================================================================

local function setRoleDeployed(roleName, deployed)
	local item = Items[roleName]
	if not item or not item.Root or not item.Root.Parent then return end

	-- Cancel any in-progress tween for this role
	local activeTween = ActiveTweens[roleName]
	if activeTween then
		activeTween:Cancel()
		ActiveTweens[roleName] = nil
	end

	local targetCFrame = deployed and item.DeployedCFrame or item.RetractedCFrame

	-- Tween the root part's CFrame
	local tween = TweenService:Create(item.Root, item.TweenInfo, {
		CFrame = targetCFrame,
	})
	ActiveTweens[roleName] = tween
	tween:Play()
	tween.Completed:Connect(function()
		if ActiveTweens[roleName] == tween then
			ActiveTweens[roleName] = nil
		end
	end)

	-- Tween extra parts relative to the root
	for _, part in ipairs(item.Parts or {}) do
		if part and part.Parent then
			local offset = item.RetractedCFrame:ToObjectSpace(part.CFrame)
			local partTarget = targetCFrame:ToWorldSpace(offset)
			local partTween = TweenService:Create(part, item.TweenInfo, {
				CFrame = partTarget,
			})
			partTween:Play()
		end
	end

	debugLog("Deploy", roleName .. ": " .. (deployed and "DEPLOYED" or "RETRACTED"))
end

local function applyVisuals()
	for _, roleName in ipairs(ROLE_ORDER) do
		local doorState = DoorStateValues[roleName]
		local isOpen = doorState and doorState.Value or false
		setRoleDeployed(roleName, isOpen)
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
		warn("[PowerSteps] Could not find vehicle model")
		return
	end

	findDoorStateValues(StateContainer)
	setupAllRoles()

	-- Connect to door state changes
	for _, roleName in ipairs(ROLE_ORDER) do
		local doorState = DoorStateValues[roleName]
		if doorState then
			doorState.Changed:Connect(function()
				applyVisuals()
			end)
		end
	end

	applyVisuals()
	debugLog("Startup", "PowerSteps plugin initialized successfully")
end

startup()
