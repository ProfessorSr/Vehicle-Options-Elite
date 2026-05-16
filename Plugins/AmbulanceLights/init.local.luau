 
-- V O E   P L U G I N S • AmbulanceLights
-- DATE (UTC):
--
-- DESCRIPTION:
-- Plugin entry point.
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)

-- - Clean, modular, no deprecated code

--====================================================================
-- Module Requires
--====================================================================

local Tags = require(script:WaitForChild("Tags"))
local Config = require(script:WaitForChild("Config"))
local PluginSounds = require(script:WaitForChild("Sounds"))

if Config and Config.Enabled == false then
	warn("[AmbulanceLights] Plugin disabled via config")
	return
end

--====================================================================
-- Services
--====================================================================

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

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

-- State Management
local STATE_DEFS = {
    EmergencyOn = { ClassName = "BoolValue", Default = false },
}
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
	print(string.format("[AmbulanceLights][%s] %s", category, message))
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
    value:SetAttribute("VOE_Owner", "AmbulanceLights")
    value:SetAttribute("VOE_Type", "State")
    if className == "BoolValue" then value.Value = defaultValue or false end
    return value
end

local function initializeStateValues()
    if not StateContainer then return end
    for stateName, spec in pairs(STATE_DEFS) do
        StateValues[stateName] = ensureStateValue(StateContainer, stateName, spec.ClassName, spec.Default)
    end
end

--====================================================================
-- Light Mapping Functions
--====================================================================

local function resolveBasePart(inst)
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then return inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart") end
    if inst:IsA("Attachment") then return inst.Parent end
    if inst:IsA("Light") then local parent = inst.Parent; if parent and parent:IsA("Attachment") then return parent.Parent end; return parent end
    return nil
end

local function ensureSpotlight(part, profile, profileName)
    if not profile then profile = Config.Lights.Emergency end
    local attachmentName = "VOE_LightAttachment"
    local attachment = part:FindFirstChild(attachmentName)
    if not attachment or not attachment:IsA("Attachment") then
        attachment = Instance.new("Attachment")
        attachment.Name = attachmentName
        attachment.Parent = part
    end
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
    spot.Color = profile.Color or Color3.fromRGB(255, 255, 255)
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
    MappedLights = {
        Front = mapLightsByTag(Tags.Required.Front_Tag, Config.Lights.Emergency, "AmbulanceFront"),
        Side = mapLightsByTag(Tags.Required.Side_Tag, Config.Lights.Emergency, "AmbulanceSide"),
        SideLeft = mapLightsByTag(Tags.Required.SideLeft_Tag, Config.Lights.Emergency, "AmbulanceSideLeft"),
        SideRight = mapLightsByTag(Tags.Required.SideRight_Tag, Config.Lights.Emergency, "AmbulanceSideRight"),
        Rear = mapLightsByTag(Tags.Required.Rear_Tag, Config.Lights.Emergency, "AmbulanceRear"),
        Main = mapLightsByTag(Tags.Required.Main_Tag, Config.Lights.Emergency, "AmbulanceMain"),
    }
end

-- Light Control
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

local function applyAmbulanceLights()
    if StateValues.EmergencyOn.Value then
        enableLights(MappedLights.Front)
        enableLights(MappedLights.Side)
        enableLights(MappedLights.SideLeft)
        enableLights(MappedLights.SideRight)
        enableLights(MappedLights.Rear)
        enableLights(MappedLights.Main)
    else
        disableLights(MappedLights.Front)
        disableLights(MappedLights.Side)
        disableLights(MappedLights.SideLeft)
        disableLights(MappedLights.SideRight)
        disableLights(MappedLights.Rear)
        disableLights(MappedLights.Main)
    end
end

-- Main Loop
local function update(dt)
    applyAmbulanceLights()
end

-- Initialization
local function startup()
    local runtimeCar, runtimeValues = findRuntimeCarAndValues()
    Vehicle = runtimeCar
    StateContainer = runtimeValues or Vehicle
    setupPluginSounds(Vehicle)
    if not Vehicle then warn("[AmbulanceLights] Could not find vehicle model") return end
    if not StateContainer then warn("[AmbulanceLights] Could not resolve state container") return end
    initializeStateValues()
    setupLightMapping()
    RunService.Heartbeat:Connect(update)
end

startup()

