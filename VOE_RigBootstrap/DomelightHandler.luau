-- VOE-RigBootstrap • DomelightHandler
-- Server-side handler for dome light - automatic with doors

local CollectionService = game:GetService("CollectionService")

local DomelightHandler = {}

-- Configuration
local CONFIG = {
    Brightness = 1.2,
    Range = 25,
    Color = Color3.fromRGB(255, 245, 220),
    Shadows = true,
}

-- State
local Vehicle = nil
local StateContainer = nil
local MappedLights = {}
local DoorStateValues = {}

--====================================================================
-- Helper Functions
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

local function ensurePointLight(part)
    local lightName = "VOE_DomeLight"
    local light = part:FindFirstChild(lightName)
    if not light or not light:IsA("PointLight") then
        if light then light:Destroy() end
        light = Instance.new("PointLight")
        light.Name = lightName
        light.Parent = part
    end
    light.Brightness = CONFIG.Brightness
    light.Range = CONFIG.Range
    light.Color = CONFIG.Color
    light.Shadows = CONFIG.Shadows
    light.Enabled = false
    return light
end

local function mapLightsByTag(tagName)
    if not tagName or tagName == "" then return {} end
    local list = {}
    for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
        local part = resolveBasePart(inst)
        if part and Vehicle and part:IsDescendantOf(Vehicle) then
            local light = ensurePointLight(part)
            table.insert(list, {
                Light = light,
                Part = part,
                OrigMaterial = part.Material,
                OrigColor = part.Color,
            })
        end
    end
    return list
end

local function setupLightMapping()
    if not Vehicle then return end
    MappedLights = mapLightsByTag("VOE_Light_Dome")
end

--====================================================================
-- Light Control
--====================================================================

local function enableLights()
    for _, entry in ipairs(MappedLights) do
        if entry.Light and entry.Light.Parent then
            entry.Light.Enabled = true
            if entry.Part then
                entry.Part.Material = Enum.Material.Neon
                entry.Part.Color = CONFIG.Color
            end
        end
    end
end

local function disableLights()
    for _, entry in ipairs(MappedLights) do
        if entry.Light and entry.Light.Parent then
            entry.Light.Enabled = false
            if entry.Part then
                entry.Part.Material = entry.OrigMaterial
                entry.Part.Color = entry.OrigColor
            end
        end
    end
end

--====================================================================
-- State Logic
--====================================================================

local function applyLightState()
    -- Check manual domelight switch
    local manualOn = false
    local domelightValue = StateContainer and StateContainer:FindFirstChild("Domelight")
    if domelightValue and domelightValue:IsA("BoolValue") then
        manualOn = domelightValue.Value
    end
    
    -- Check if any door is open
    local anyDoorOpen = false
    for _, stateValue in pairs(DoorStateValues) do
        if stateValue.Value then
            anyDoorOpen = true
            break
        end
    end
    
    if anyDoorOpen or manualOn then
        enableLights()
    else
        disableLights()
    end
end

local function findDoorStateValues()
    if not StateContainer then return end
    
    for _, name in ipairs({"DoorFL", "DoorFR", "DoorRL", "DoorRR"}) do
        local stateValue = StateContainer:FindFirstChild(name)
        if stateValue and stateValue:IsA("BoolValue") then
            DoorStateValues[name] = stateValue
        end
    end
end

--====================================================================
-- Initialization
--====================================================================

function DomelightHandler.Initialize(vehicle, stateContainer)
    Vehicle = vehicle
    StateContainer = stateContainer
    
    findDoorStateValues()
    setupLightMapping()
    
    -- Connect to door state changes
    for name, stateValue in pairs(DoorStateValues) do
        stateValue.Changed:Connect(applyLightState)
    end
    
    -- Connect to manual domelight switch
    local domelightValue = StateContainer and StateContainer:FindFirstChild("Domelight")
    if domelightValue and domelightValue:IsA("BoolValue") then
        domelightValue.Changed:Connect(applyLightState)
    end
    
    -- Apply initial state
    applyLightState()
    
    print("[DomelightHandler] Initialized successfully")
end

return DomelightHandler