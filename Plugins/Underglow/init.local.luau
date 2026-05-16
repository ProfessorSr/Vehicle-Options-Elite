
-- PPPP    SSSS    11        PPPP   L      U   U   GGGG   III  N   N
-- P   P  S         1        P   P  L      U   U  G        I   NN  N
-- PPPP    SSS      1        PPPP   L      U   U  G  GG    I   N N N
-- P         S      1        P      L      U   U  G   G    I   N  NN
-- P      SSSS     111       P      LLLLL   UUU    GGGG   III  N   N
--
-- V O E   P L U G I N S • Underglow
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles neon underglow mapping and activation
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
	warn("[Underglow] Plugin disabled via config")
	return
end

--====================================================================
-- Services
--====================================================================

local RunService = game:GetService("RunService")
local UserInputService = RunService:IsClient() and game:GetService("UserInputService") or nil
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

--====================================================================
-- Context Resolution
--====================================================================

local function findRuntimeCarAndValues()
	local pluginContainer = script.Parent
	local carValue = pluginContainer:FindFirstChild("Car")

	if carValue and carValue:IsA("ObjectValue") and carValue.Value and carValue.Value:IsA("Model") then
		local vehicle = carValue.Value
		-- Check for VOE_State folder
		local voeState = vehicle:FindFirstChild("VOE_State")
		if voeState then
			return vehicle, voeState
		end
		return vehicle, nil
	end
	return nil, nil
end

--====================================================================
-- Configuration
--====================================================================

local STATE_DEFS = {
    UnderglowOn = { ClassName = "BoolValue", Default = false },
}

--====================================================================
-- State Management
--====================================================================

local Vehicle = nil
local StateValues = {}
local MappedParts = {}
local StateContainer = nil
local ColorTime = 0 -- Track time for color cycling

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
    value:SetAttribute("VOE_Owner", "Underglow")
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
    return nil
end

local function mapUnderglowParts()
    if not Vehicle then return end
    MappedParts = {}
    for _, inst in ipairs(CollectionService:GetTagged(Tags.Required.Underglow_Tag)) do
        local part = resolveBasePart(inst)
        if part and Vehicle and part:IsDescendantOf(Vehicle) then
            table.insert(MappedParts, {
                Part = part,
                OrigMaterial = part.Material,
                OrigColor = part.Color,
            })
        end
    end
end

local function getCurrentColor()
	-- Get the current color based on mode
	if Config.Mode == "Single" then
		return Config.SingleColor.Color
	elseif Config.Mode == "Multi" then
		local colors = Config.MultiColor.Colors
		local speed = Config.MultiColor.CycleSpeed
		local style = Config.MultiColor.TransitionStyle
		
		if #colors == 0 then
			return Color3.fromRGB(255, 255, 255)
		end
		
		-- Calculate position in the color cycle (0 to 1)
		local cycleProgress = (ColorTime % speed) / speed
		local colorCount = #colors
		
		if style == "Fade" then
			-- Smooth transition between colors
			local totalPositions = colorCount
			local exactPosition = cycleProgress * totalPositions
			local colorIndex = math.floor(exactPosition) % colorCount + 1
			local nextColorIndex = (colorIndex % colorCount) + 1
			local blendFactor = exactPosition - math.floor(exactPosition)
			
			local color1 = colors[colorIndex]
			local color2 = colors[nextColorIndex]
			
			-- Lerp between colors
			return color1:Lerp(color2, blendFactor)
		else
			-- Solid: stay on each color
			local colorIndex = math.floor(cycleProgress * colorCount) % colorCount + 1
			return colors[colorIndex]
		end
	end
	
	return Color3.fromRGB(255, 255, 255)
end

local function enableUnderglow()
    local currentColor = getCurrentColor()
    
    for _, entry in ipairs(MappedParts) do
        entry.Part.Material = Enum.Material.Neon
        entry.Part.Color = currentColor

        -- Add or reuse downward Attachment
        local attachment = entry.Part:FindFirstChild("UnderglowAttachment")
        if not attachment then
            attachment = Instance.new("Attachment")
            attachment.Name = "UnderglowAttachment"
            -- Offset slightly below the part
            attachment.Position = Vector3.new(0, -0.2, 0)
            attachment.Parent = entry.Part
        end

        -- Add or reuse SpotLight
        local spot = attachment:FindFirstChild("UnderglowSpotLight")
        if not spot then
            spot = Instance.new("SpotLight")
            spot.Name = "UnderglowSpotLight"
            spot.Parent = attachment
        end
        spot.Brightness = Config.Underglow.Brightness or 1
        spot.Range = Config.Underglow.Range or 8
        spot.Color = currentColor
        spot.Angle = 140 -- Wide angle for underglow
        spot.Face = Enum.NormalId.Bottom
        spot.Enabled = true

        -- Optional: keep SurfaceLight for extra glow
        local surf = entry.Part:FindFirstChild("UnderglowLight")
        if not surf then
            surf = Instance.new("SurfaceLight")
            surf.Name = "UnderglowLight"
            surf.Brightness = Config.Underglow.Brightness or 1
            surf.Range = Config.Underglow.Range or 8
            surf.Color = currentColor
            surf.Parent = entry.Part
        end
        surf.Color = currentColor
        surf.Enabled = true
    end
end

local function disableUnderglow()
    for _, entry in ipairs(MappedParts) do
        entry.Part.Material = entry.OrigMaterial
        entry.Part.Color = entry.OrigColor
        local surf = entry.Part:FindFirstChild("UnderglowLight")
        if surf then surf.Enabled = false end
        local attachment = entry.Part:FindFirstChild("UnderglowAttachment")
        if attachment then
            local spot = attachment:FindFirstChild("UnderglowSpotLight")
            if spot then spot.Enabled = false end
        end
    end
end

local function applyUnderglow()
    if StateValues.UnderglowOn.Value then
        enableUnderglow()
    else
        disableUnderglow()
    end
end

local function update(dt)
    -- Update color time for multi-color mode
    if Config.Mode == "Multi" and StateValues.UnderglowOn.Value then
        ColorTime = ColorTime + dt
    end
    applyUnderglow()
end

local function handleKeybind(input, processed)
    if processed or not StateValues.UnderglowOn then return end
    local keybinds = Config.Keybinds or {}
    if input.KeyCode == (keybinds.ToggleUnderglow or Enum.KeyCode.U) then
        StateValues.UnderglowOn.Value = not StateValues.UnderglowOn.Value
        print("[Underglow] Toggled UnderglowOn to", StateValues.UnderglowOn.Value)
    end
end

local function startup()
    local runtimeCar, runtimeValues = findRuntimeCarAndValues()
    Vehicle = runtimeCar
    StateContainer = runtimeValues or Vehicle
    if not Vehicle then warn("[Underglow] Could not find vehicle model") return end
    if not StateContainer then warn("[Underglow] Could not resolve state container") return end
    initializeStateValues()
    mapUnderglowParts()
    if UserInputService then
        UserInputService.InputBegan:Connect(handleKeybind)
    end
    RunService.Heartbeat:Connect(update)
end

startup()
