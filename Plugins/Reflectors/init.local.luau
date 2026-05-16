 
-- V O E   P L U G I N S • Reflectors
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles passive reflector mapping and state
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)

-- - Clean, modular, no deprecated code

--====================================================================
-- Module Requires
--====================================================================

local Tags = require(script:WaitForChild("Tags"))
local Config = require(script:WaitForChild("Config"))

if Config and Config.Enabled == false then
	warn("[Reflectors] Plugin disabled via config")
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

local STATE_DEFS = {
    HeadlightMode = { ClassName = "IntValue", Default = 0 },
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

local function debugLog(category, message)
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
    value:SetAttribute("VOE_Owner", "Reflectors")
    value:SetAttribute("VOE_Type", "State")
    if className == "IntValue" then value.Value = defaultValue or 0 end
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

local function mapReflectorsByTag(tagName, profile, lightListName)
    if not tagName or tagName == "" then return {} end
    local list = {}
    for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
        local part = resolveBasePart(inst)
        if part and Vehicle and part:IsDescendantOf(Vehicle) then
            table.insert(list, {
                Part = part,
                Profile = profile,
                OrigMaterial = part.Material,
                OrigColor = part.Color,
            })
        end
    end
    return list
end

local function setupReflectorMapping()
    if not Vehicle then return end
    MappedLights = {
        Low = mapReflectorsByTag(Tags.Required.ReflectorLow.Tag, Config.Reflectors.Low, "ReflectorLow"),
        High = mapReflectorsByTag(Tags.Required.ReflectorHigh.Tag, Config.Reflectors.High, "ReflectorHigh"),
        Brake = mapReflectorsByTag(Tags.Required.ReflectorBrake.Tag, Config.Reflectors.Brake, "ReflectorBrake"),
        Reverse = mapReflectorsByTag(Tags.Required.ReflectorReverse.Tag, Config.Reflectors.Reverse, "ReflectorReverse"),
        SignalLeft = mapReflectorsByTag(Tags.Required.ReflectorSignalLeft.Tag, Config.Reflectors.SignalLeft, "ReflectorSignalLeft"),
        SignalRight = mapReflectorsByTag(Tags.Required.ReflectorSignalRight.Tag, Config.Reflectors.SignalRight, "ReflectorSignalRight"),
    }
end

local function applyReflectorState()
    local mode = StateValues.HeadlightMode.Value or 0
    if mode >= 2 then
        for _, entry in ipairs(MappedLights.Low) do
            entry.Part.Material = Enum.Material.Neon
            entry.Part.Color = entry.Profile.Color or entry.Part.Color
        end
    else
        for _, entry in ipairs(MappedLights.Low) do
            entry.Part.Material = entry.OrigMaterial
            entry.Part.Color = entry.OrigColor
        end
    end
    if mode == 3 then
        for _, entry in ipairs(MappedLights.High) do
            entry.Part.Material = Enum.Material.Neon
            entry.Part.Color = entry.Profile.Color or entry.Part.Color
        end
    else
        for _, entry in ipairs(MappedLights.High) do
            entry.Part.Material = entry.OrigMaterial
            entry.Part.Color = entry.OrigColor
        end
    end
    -- Brake, reverse, signal reflectors can be handled similarly if needed
end

local function update(dt)
    applyReflectorState()
end

local function startup()
    local runtimeCar, runtimeValues = findRuntimeCarAndValues()
    Vehicle = runtimeCar
    StateContainer = runtimeValues or Vehicle
    if not Vehicle then warn("[Reflectors] Could not find vehicle model") return end
    if not StateContainer then warn("[Reflectors] Could not resolve state container") return end
    initializeStateValues()
    setupReflectorMapping()
    RunService.Heartbeat:Connect(update)
	end

startup()
