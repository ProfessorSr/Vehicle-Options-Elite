-- VOE-RigBootstrap • PuddleLightsHandler
-- Server-side handler for puddle lights - automatic with doors

local CollectionService = game:GetService("CollectionService")

local PuddleLightsHandler = {}

-- Configuration
local CONFIG = {
    Brightness = 1.4,
    Range = 18,
    Angle = 95,
    Color = Color3.fromRGB(255, 245, 230),
    Shadows = true,
}

-- State
local Vehicle = nil
local StateContainer = nil
local MappedLights = {
    PuddleLeft = {},
    PuddleRight = {},
}
local DoorStateValues = {}

--====================================================================
-- Helper Functions
--====================================================================

local function resolveBasePart(inst)
    if inst:IsA("BasePart") then return inst
    elseif inst:IsA("Model") then return inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart")
    elseif inst:IsA("Attachment") then return inst.Parent
    end
    return nil
end

local function ensureSpotlight(part)
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
    
    spot.Brightness = CONFIG.Brightness
    spot.Range = CONFIG.Range
    spot.Angle = CONFIG.Angle
    spot.Color = CONFIG.Color
    spot.Shadows = CONFIG.Shadows
    spot.Enabled = false
    return spot
end

local function mapLightsByTag(tagName)
    if not tagName or tagName == "" then return {} end
    local list = {}
    for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
        local part = resolveBasePart(inst)
        if part and Vehicle and part:IsDescendantOf(Vehicle) then
            local spot = ensureSpotlight(part)
            table.insert(list, {
                Spot = spot,
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
    MappedLights.PuddleLeft = mapLightsByTag("VOE_Light_PuddleLeft")
    MappedLights.PuddleRight = mapLightsByTag("VOE_Light_PuddleRight")
end

--====================================================================
-- Light Control
--====================================================================

local function enableLights(lightList)
    for _, entry in ipairs(lightList) do
        if entry.Spot and entry.Spot.Parent then
            entry.Spot.Enabled = true
            if entry.Part then
                entry.Part.Material = Enum.Material.Neon
                entry.Part.Color = CONFIG.Color
            end
        end
    end
end

local function disableLights(lightList)
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

--====================================================================
-- State Logic
--====================================================================

local function applyLightState()
    -- Left puddle lights: ON when DoorFL or DoorRL is open
    local leftDoorsOpen = (DoorStateValues.DoorFL and DoorStateValues.DoorFL.Value) or 
                          (DoorStateValues.DoorRL and DoorStateValues.DoorRL.Value)
    if leftDoorsOpen then
        enableLights(MappedLights.PuddleLeft)
    else
        disableLights(MappedLights.PuddleLeft)
    end
    
    -- Right puddle lights: ON when DoorFR or DoorRR is open
    local rightDoorsOpen = (DoorStateValues.DoorFR and DoorStateValues.DoorFR.Value) or 
                           (DoorStateValues.DoorRR and DoorStateValues.DoorRR.Value)
    if rightDoorsOpen then
        enableLights(MappedLights.PuddleRight)
    else
        disableLights(MappedLights.PuddleRight)
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

function PuddleLightsHandler.Initialize(vehicle, stateContainer)
    Vehicle = vehicle
    StateContainer = stateContainer
    
    findDoorStateValues()
    setupLightMapping()
    
    -- Connect to door state changes
    for name, stateValue in pairs(DoorStateValues) do
        stateValue.Changed:Connect(applyLightState)
    end
    
    -- Apply initial state
    applyLightState()
    
    print("[PuddleLightsHandler] Initialized successfully")
end

return PuddleLightsHandler