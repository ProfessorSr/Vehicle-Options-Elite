 
-- V O E   P L U G I N S • Headlights
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles headlight mode cycling, DRL toggle, parking lights, and license plate lights
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
	warn("[Headlights] Plugin disabled via config")
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
local ATTACHMENT_YAW_OVERRIDES = Config.AttachmentYawOverrides or {}

local STATE_DEFS = {
	HeadlightMode = { ClassName = "IntValue", Default = 0 },
	DRLOn = { ClassName = "BoolValue", Default = false },
}

--====================================================================
-- State Management
--====================================================================

local Vehicle = nil
local StateValues = {}
local MappedLights = {}
local StateContainer = nil

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
	print(string.format("[Headlights][%s] %s", category, message))
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
	value:SetAttribute("VOE_Owner", "Headlights")
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

	-- Create all state values
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
	if not profile then profile = Config.Lights.Low end

	-- Use dedicated attachments for special-direction beams.
	local attachmentName
	if profileName == "High" then
		attachmentName = "VOE_LightAttachment_High"
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
	if profileName == "LicensePlate" then
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

	spot.Brightness = profile.Brightness or 1
	spot.Range = profile.Range or 30
	spot.Angle = profile.Angle or 45
	spot.Color = profile.Color or Color3.fromRGB(255, 255, 200)
	spot.Shadows = profile.Shadows ~= false
	spot.Enabled = false

	return spot
end

local function mapLightsByTag(tagName, profile, lightListName)
	if not tagName or tagName == "" then return {} end

	local list = {}
	for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
		local part = resolveBasePart(inst)
		if part and Vehicle and part:IsDescendantOf(Vehicle) then
			local spot = ensureSpotlight(part, profile, lightListName)
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
	MappedLights = {}

	       -- Headlight groups
	       MappedLights.Headlight = {
		       DRL = mapLightsByTag(Tags.Required.DRL_Tag, Config.Lights.DRL or Config.Lights.Low, "DRL"),
		       Low = mapLightsByTag(Tags.Required.Low_Tag, Config.Lights.Low, "Low"),
		       High = mapLightsByTag(Tags.Required.High_Tag, Config.Lights.High, "High"),
	       }
	       -- Parking lights
	       MappedLights.Parking = mapLightsByTag(Tags.Required.Parking_Tag, Config.Lights.Parking or Config.Lights.Low, "Parking")
	       -- License plate lights
	       MappedLights.LicensePlate = mapLightsByTag(Tags.Required.LicensePlate_Tag, Config.Lights.LicensePlate or Config.Lights.Low, "LicensePlate")
	       -- Reflectors
	       MappedLights.Reflectors = {
		       Low = mapLightsByTag(Tags.Required.ReflectorLow_Tag, Config.Lights.Low, "ReflectorLow"),
		       High = mapLightsByTag(Tags.Required.ReflectorHigh_Tag, Config.Lights.High, "ReflectorHigh"),
	       }
	       -- Taillights
	       MappedLights.Taillight = mapLightsByTag(Tags.Required.Taillight_Tag, Config.Lights.Taillight or Config.Lights.Parking, "Taillight")
end

local function getDriveSeatForVehicle(vehicle)
	if not vehicle then return nil end
	local direct = vehicle:FindFirstChild("DriveSeat")
	if direct and direct:IsA("VehicleSeat") then
		return direct
	end
	for _, inst in ipairs(vehicle:GetDescendants()) do
		if inst:IsA("VehicleSeat") and inst.Name == "DriveSeat" then
			return inst
		end
	end
	for _, inst in ipairs(vehicle:GetDescendants()) do
		if inst:IsA("VehicleSeat") then
			return inst
		end
	end
	return nil
end

local function isLocalPlayerDrivingVehicle()
	local player = Players.LocalPlayer
	if not player or not player.Character or not Vehicle then
		return false
	end

	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	local seat = getDriveSeatForVehicle(Vehicle)
	if not seat then
		return false
	end

	return seat.Occupant == humanoid
end

--====================================================================
-- Light Control Functions
--====================================================================

local function enableLights(lightList)
	if not lightList then return end
	for _, entry in ipairs(lightList) do
		if entry.Spot and entry.Spot.Parent then
			entry.Spot.Enabled = true
			-- Optional: glow effect on part
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
			-- Restore original material
			if entry.Part then
				entry.Part.Material = entry.OrigMaterial
				entry.Part.Color = entry.OrigColor
			end
		end
	end
end

local function applyLightingState()
	if not StateValues.HeadlightMode then return end

	local mode = StateValues.HeadlightMode.Value or 0

	-- True when parking or any higher mode is active (used for license plate)
	local lightsActive = mode == 1 or mode == 2 or mode == 3

	-- Headlight beams (mode cycle: 0=Off, 1=Parking, 2=Low, 3=High)
	if mode == 1 then
		enableLights(MappedLights.Parking)
		disableLights(MappedLights.Headlight.Low)
		disableLights(MappedLights.Headlight.High)
	elseif mode == 2 then
		enableLights(MappedLights.Parking)
		enableLights(MappedLights.Headlight.Low)
		disableLights(MappedLights.Headlight.High)
	elseif mode == 3 then
		enableLights(MappedLights.Parking)
		disableLights(MappedLights.Headlight.Low)
		enableLights(MappedLights.Headlight.High)
	else -- mode 0 (off)
		disableLights(MappedLights.Parking)
		disableLights(MappedLights.Headlight.Low)
		disableLights(MappedLights.Headlight.High)
	end

	-- DRL (separate toggle, independent of headlight cycle)
	if StateValues.DRLOn and StateValues.DRLOn.Value then
		enableLights(MappedLights.Headlight.DRL)
	else
		disableLights(MappedLights.Headlight.DRL)
	end

	       -- License plate (on when parking or higher, including auto night)
	       if lightsActive then
		       enableLights(MappedLights.LicensePlate)
	       else
		       disableLights(MappedLights.LicensePlate)
	       end

	       -- Taillights (on with parking or higher)
	       if lightsActive then
		       enableLights(MappedLights.Taillight)
	       else
		       disableLights(MappedLights.Taillight)
	       end

	       -- Reflectors mirror their corresponding lights
	       if mode >= 2 then
		       enableLights(MappedLights.Reflectors.Low)
	       else
		       disableLights(MappedLights.Reflectors.Low)
	       end

	       if mode == 3 then
		       enableLights(MappedLights.Reflectors.High)
	       else
		       disableLights(MappedLights.Reflectors.High)
	       end
end

--====================================================================
-- Keybind Handling
--====================================================================

local function handleKeybind(input, gameProcessed)
	if gameProcessed then return end
	if not isLocalPlayerDrivingVehicle() then return end

	local keyCode = input.KeyCode
	local keybinds = Config.Keybinds or {}

	if keyCode == (keybinds.ToggleHeadlights or Enum.KeyCode.L) then
		StateValues.HeadlightMode.Value = (StateValues.HeadlightMode.Value + 1) % 4
		if DEBUG_CONFIG.LogKeybinds ~= false then
			debugLog("Input", "Headlight mode set to " .. tostring(StateValues.HeadlightMode.Value))
		end
	elseif keyCode == (keybinds.ToggleDRL or Enum.KeyCode.G) then
		StateValues.DRLOn.Value = not StateValues.DRLOn.Value
		if DEBUG_CONFIG.LogKeybinds ~= false then
			debugLog("Input", "DRL " .. (StateValues.DRLOn.Value and "ON" or "OFF"))
		end
	end
end

--====================================================================
-- Initialization
--====================================================================

local function startup()
	local runtimeCar, runtimeValues = findRuntimeCarAndValues()

	Vehicle = runtimeCar
	StateContainer = runtimeValues or Vehicle
	setupPluginSounds(Vehicle)
	if not Vehicle then
		warn("[Headlights] Could not find vehicle model")
		return
	end

	if not StateContainer then
		warn("[Headlights] Could not resolve state container")
		return
	end

	initializeStateValues()
	setupLightMapping()

	-- Connect keybind listener (client only)
	if UserInputService then
		UserInputService.InputBegan:Connect(handleKeybind)
	end

	-- Connect state changes to trigger updates
	for _, stateValue in pairs(StateValues) do
		if stateValue then
			stateValue.Changed:Connect(function(newValue)
				if DEBUG_CONFIG.LogStateChanges ~= false then
					debugLog("State", stateValue.Name .. " -> " .. tostring(newValue))
				end
				applyLightingState()
			end)
		end
	end

	-- Initial application
	applyLightingState()
end

startup()

