 
-- V O E   P L U G I N S • Windows
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles window opening/closing with hinge constraints or sliding
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)

-- - Clean, modular, no deprecated code

--====================================================================
-- Module Requires
--====================================================================

local Config = require(script:WaitForChild("Config"))
local keybindsModule = script.Parent and script.Parent:FindFirstChild("Keybinds") or script:FindFirstChild("Keybinds")
local Keybinds = keybindsModule and require(keybindsModule) or {}
local Tags = require(script:WaitForChild("Tags"))
local PluginSounds = require(script:WaitForChild("Sounds"))

if Config and Config.Enabled == false then
	warn("[Windows] Plugin disabled via config")
	return
end

--====================================================================
-- Services
--====================================================================

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local UserInputService = RunService:IsClient() and game:GetService("UserInputService") or nil

--====================================================================
-- Configuration
--====================================================================

local DEBUG_CONFIG = Config.Debug or {}
local ROLE_ORDER = {"WindowFL", "WindowFR", "WindowRL", "WindowRR"}

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
	print(string.format("[Windows][%s] %s", category, message))
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
	value:SetAttribute("VOE_Owner", "Windows")
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
	local rootTag = Tags.Required["Windows_" .. roleName .. "_Root"]
	local partTag = Tags.Required["Windows_" .. roleName .. "_Part"]
	if not rootTag then return end
	
	local roleConfig = Config.Presets[roleName] or {}
	local roots = collectTaggedParts(rootTag)
	local parts = collectTaggedParts(partTag)
	
	Items[roleName] = {}
	
	for _, rootPart in ipairs(roots) do
		-- Setup based on mode
		local mode = string.upper(roleConfig.Mode or "SLIDING")
		local item = {
			Part = rootPart,
			Mode = mode,
		}
		
		if mode == "HINGED" then
			-- Find existing hinge created by VOE_RigBootstrap
			local hinge = findHinge(rootPart, roleName)
			if hinge then
				hinge.AngularSpeed = tonumber(rootPart:GetAttribute(Tags.Optional.OpenSpeedAttribute)) or tonumber(roleConfig.Speed) or 2.8
				hinge.ServoMaxTorque = tonumber(rootPart:GetAttribute(Tags.Optional.OpenTorqueAttribute)) or tonumber(roleConfig.OpenTorque) or 12000
				hinge.TargetAngle = tonumber(roleConfig.CloseAngle) or 0
				item.Hinge = hinge
				item.OpenAngle = tonumber(rootPart:GetAttribute(Tags.Optional.OpenAngleAttribute)) or tonumber(roleConfig.OpenAngle) or 25
				item.CloseAngle = tonumber(rootPart:GetAttribute("VOE_CloseAngle")) or tonumber(roleConfig.CloseAngle) or 0
			end
		else
			-- Sliding mode - check for PrismaticConstraint first
			local prismatic = rootPart:FindFirstChild("WindowSlideConstraint")
			if prismatic and prismatic:IsA("PrismaticConstraint") then
				item.Prismatic = prismatic
				item.OpenDistance = tonumber(rootPart:GetAttribute(Tags.Optional.SlideDistanceAttribute)) or tonumber(roleConfig.OpenDistance) or 1.8
				prismatic.UpperLimit = item.OpenDistance
				debugLog("Setup", "Using PrismaticConstraint for " .. roleName)
			else
				-- Fallback to simple position tweening
				item.OpenDistance = tonumber(rootPart:GetAttribute(Tags.Optional.SlideDistanceAttribute)) or tonumber(roleConfig.OpenDistance) or 1.8
				item.ClosedCFrame = rootPart.CFrame
				debugLog("Setup", "Using tweening for " .. roleName)
			end
		end
		
		table.insert(Items[roleName], item)
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
		if not (item.Part and item.Part.Parent) then continue end
		
		if item.Mode == "HINGED" and item.Hinge and item.Hinge.Parent then
			item.Hinge.TargetAngle = isOpen and item.OpenAngle or (item.CloseAngle or 0)
		elseif item.Prismatic then
			-- Use PrismaticConstraint for sliding
			local targetPosition = isOpen and item.OpenDistance or 0
			local tweenTime = tonumber(item.Part:GetAttribute(Tags.Optional.TweenTimeAttribute)) or (Config.Presets[roleName] or {}).TweenTime or 0.5
			
			-- Animate the prismatic constraint
			local tween = TweenService:Create(item.Prismatic, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TargetPosition = targetPosition
			})
			tween:Play()
			debugLog("Action", roleName .. " sliding to " .. tostring(targetPosition))
		else
			-- Sliding mode - tween position (fallback)
			local roleConfig = Config.Presets[roleName] or {}
			local openDistance = item.OpenDistance or 1.8
			local slideAxis = roleConfig.OpenAngleAxis or "Z"
			
			-- Calculate target CFrame
			local closedCF = item.ClosedCFrame
			if not closedCF then
				closedCF = item.Part.CFrame
				item.ClosedCFrame = closedCF
			end
			
			local offset = isOpen and openDistance or 0
			local targetCF
			if slideAxis == "X" then
				targetCF = closedCF * CFrame.new(offset, 0, 0)
			elseif slideAxis == "Y" then
				targetCF = closedCF * CFrame.new(0, offset, 0)
			else
				targetCF = closedCF * CFrame.new(0, 0, offset)
			end
			
			-- Tween the part
			local tweenTime = tonumber(item.Part:GetAttribute(Tags.Optional.TweenTimeAttribute)) or roleConfig.TweenTime or 0.5
			local tween = TweenService:Create(item.Part, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = targetCF})
			tween:Play()
		end
	end
end

local function toggleByRole(roleName)
	local v = StateValues[roleName]
	if not v then return false end
	v.Value = not v.Value
	return true
end

local function toggleAll()
	local anyOpen = false
	for _, roleName in ipairs(ROLE_ORDER) do
		if StateValues[roleName] and StateValues[roleName].Value then
			anyOpen = true
			break
		end
	end
	local nextValue = not anyOpen
	for _, roleName in ipairs(ROLE_ORDER) do
		if StateValues[roleName] then
			StateValues[roleName].Value = nextValue
		end
	end
	return true
end

local function applyVisuals()
	for _, roleName in ipairs(ROLE_ORDER) do
		local isOpen = StateValues[roleName] and StateValues[roleName].Value or false
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
	local keybindMap = Keybinds.KeybindMap or {
		["ToggleWindowFL"] = "WindowFL",
		["ToggleWindowFR"] = "WindowFR",
		["ToggleWindowRL"] = "WindowRL",
		["ToggleWindowRR"] = "WindowRR",
	}
	
	-- Check if vehicle has power (IsOn or ACC)
	local hasPower = false
	if Vehicle then
		-- Check A-Chassis Interface for IsOn
		local tune = Vehicle:FindFirstChild("A-Chassis Tune")
		if tune then
			local gui = tune:FindFirstChild("A-Chassis Interface")
			if gui then
				local isOn = gui:FindFirstChild("IsOn")
				if isOn then
					-- Check if engine is on
					if isOn.Value then
						hasPower = true
					end
					-- Check for ACC (accessory on)
					local acc = isOn:FindFirstChild("ACC")
					if acc and acc.Value then
						hasPower = true
					end
				end
			end
		end
		-- Also check VOE_State for AccessoryOn
		local voeState = Vehicle:FindFirstChild("VOE_State")
		if voeState then
			local accOn = voeState:FindFirstChild("AccessoryOn")
			if accOn and accOn.Value then
				hasPower = true
			end
		end
	end
	
	-- Check PowerActions config
	local powerActions = Config.PowerActions or {}
	local needsPower = powerActions.ToggleWindowFL or powerActions.ToggleWindowFR or powerActions.ToggleWindowRL or powerActions.ToggleWindowRR or powerActions.ToggleWindowsAll
	
--	if needsPower and not hasPower then
--		debugLog("Input", "Windows require power (Acc or Eng on)")
--		return
--	end
	
	local keybindMap = {
		["ToggleWindowFL"] = "WindowFL",
		["ToggleWindowFR"] = "WindowFR",
		["ToggleWindowRL"] = "WindowRL",
		["ToggleWindowRR"] = "WindowRR",
	}
	
	for keybindName, roleName in pairs(keybindMap) do
		if keyCode == (keybinds[keybindName] or Enum.KeyCode.Unknown) then
			toggleByRole(roleName)
			if DEBUG_CONFIG.LogKeybinds ~= false then
				debugLog("Input", roleName .. " toggled")
			end
			return
		end
	end
	
	if keyCode == (keybinds.ToggleWindowsAll or Enum.KeyCode.K) then
		toggleAll()
		if DEBUG_CONFIG.LogKeybinds ~= false then
			debugLog("Input", "All windows toggled")
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
		warn("[Windows] Could not find vehicle model")
		return
	end
	
	initializeStateValues()
	setupAllRoles()
	
	-- after setupAllRoles()
	for _, roleName in ipairs(ROLE_ORDER) do
		for _, item in ipairs(Items[roleName] or {}) do
			if item.Prismatic then
				item.Prismatic.TargetPosition = 0
			elseif item.Hinge then
				item.Hinge.TargetAngle = item.CloseAngle or 0
			end
		end
	end
	
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
	debugLog("Startup", "Windows plugin initialized successfully")
end

startup()