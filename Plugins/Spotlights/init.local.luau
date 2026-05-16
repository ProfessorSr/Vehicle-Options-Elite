
-- V O E   P L U G I N S • Spotlights
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles spotlight on/off state and arm/lamp rotation.
-- Left and Right spotlights each toggle independently.
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)
-- - Arm/lamp rotation rotates the physical part the attachment belongs to
-- - Keybinds configured in Config

--====================================================================
-- Module Requires
--====================================================================

local Config = require(script:WaitForChild("Config"))
local Tags = require(script:WaitForChild("Tags"))
local PluginSounds = require(script:WaitForChild("Sounds"))

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
}
local ROTATION_STEP = math.rad(5) -- 5 degrees per keypress

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
	MappedLights.Left = mapLightsByTag(Tags.Required.SpotlightLeft_Tag or "VOE_Light_SpotlightLeft", profile)
	MappedLights.Right = mapLightsByTag(Tags.Required.SpotlightRight_Tag or "VOE_Light_SpotlightRight", profile)
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
-- Arm/Lamp Rotation
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

local function setupRotation()
	if not Vehicle then return end
	local spotCfg = Config.Spotlights or {}
	for _, id in ipairs(ROLE_ORDER) do
		local cfg = spotCfg[id]
		if cfg then
			local armAttachment = findAttachmentByName(Vehicle, cfg.armAttachment or "")
			local lampAttachment = findAttachmentByName(Vehicle, cfg.lampAttachment or "")

			-- The arm/lamp parts are the parent parts of the attachments
			local armPart = armAttachment and armAttachment.Parent or nil
			local lampPart = lampAttachment and lampAttachment.Parent or nil

			RotationStates[id] = {
				armAttachment = armAttachment,
				lampAttachment = lampAttachment,
				armPart = armPart and armPart:IsA("BasePart") and armPart or nil,
				lampPart = lampPart and lampPart:IsA("BasePart") and lampPart or nil,
				armAngle = 0,
				lampAngle = 0,
				initialArmCFrame = armPart and armPart:IsA("BasePart") and armPart.CFrame or nil,
				initialLampCFrame = lampPart and lampPart:IsA("BasePart") and lampPart.CFrame or nil,
			}

			debugLog("Setup", id .. ": arm=" .. (armAttachment and armAttachment.Name or "nil")
				.. ", lamp=" .. (lampAttachment and lampAttachment.Name or "nil"))
		end
	end
end

local function rotateArm(id, delta)
	local state = RotationStates[id]
	if not state then return end

	-- Prefer rotating the physical part around the arm attachment pivot
	if state.armPart and state.armPart.Parent and state.armAttachment and state.armAttachment.Parent then
		state.armAngle = state.armAngle + delta
		local pivotPos = state.armAttachment.WorldPosition
		local currentCFrame = state.armPart.CFrame
		-- Rotate around the attachment's world position
		local offset = currentCFrame.Position - pivotPos
		local rotation = CFrame.Angles(delta, 0, 0)
		local newOffset = rotation:VectorToWorldSpace(offset)
		state.armPart.CFrame = CFrame.new(pivotPos + newOffset) * (currentCFrame - currentCFrame.Position) * rotation
	elseif state.armAttachment and state.armAttachment.Parent then
		-- Fallback: just modify attachment CFrame (visual only, no physical effect)
		state.armAngle = state.armAngle + delta
		state.armAttachment.CFrame = state.armAttachment.CFrame * CFrame.Angles(delta, 0, 0)
	end
end

local function rotateLamp(id, delta)
	local state = RotationStates[id]
	if not state then return end

	-- Prefer rotating the physical part around the lamp attachment pivot
	if state.lampPart and state.lampPart.Parent and state.lampAttachment and state.lampAttachment.Parent then
		state.lampAngle = state.lampAngle + delta
		local pivotPos = state.lampAttachment.WorldPosition
		local currentCFrame = state.lampPart.CFrame
		local offset = currentCFrame.Position - pivotPos
		local rotation = CFrame.Angles(0, delta, 0)
		local newOffset = rotation:VectorToWorldSpace(offset)
		state.lampPart.CFrame = CFrame.new(pivotPos + newOffset) * (currentCFrame - currentCFrame.Position) * rotation
	elseif state.lampAttachment and state.lampAttachment.Parent then
		-- Fallback: just modify attachment CFrame
		state.lampAngle = state.lampAngle + delta
		state.lampAttachment.CFrame = state.lampAttachment.CFrame * CFrame.Angles(0, delta, 0)
	end
end

--====================================================================
-- Keybind Handling
--====================================================================

local function handleKeybind(input, gameProcessed)
	if gameProcessed then return end
	local keyCode = input.KeyCode
	local keybinds = Config.Keybinds or {}

	-- On/off toggles
	if keyCode == (keybinds.ToggleSpotlightLeft or Enum.KeyCode.One) then
		if StateValues.SpotlightLeft then
			StateValues.SpotlightLeft.Value = not StateValues.SpotlightLeft.Value
			debugLog("Input", "SpotlightLeft " .. (StateValues.SpotlightLeft.Value and "ON" or "OFF"))
		end
		return
	elseif keyCode == (keybinds.ToggleSpotlightRight or Enum.KeyCode.Two) then
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
			local lampKeyName = cfg.lampKey
			if armKeyName and keyCode.Name == armKeyName and RotationStates[id] then
				rotateArm(id, ROTATION_STEP)
				return
			elseif lampKeyName and keyCode.Name == lampKeyName and RotationStates[id] then
				rotateLamp(id, ROTATION_STEP)
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
	debugLog("Startup", "Spotlights plugin initialized successfully")
end

startup()
