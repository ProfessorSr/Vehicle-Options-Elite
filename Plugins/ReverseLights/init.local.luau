 
-- V O E   P L U G I N S • ReverseLights
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles reverse light state, mapping, and gear monitoring
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
	warn("[ReverseLights] Plugin disabled via config")
	return
end

--====================================================================
-- Services
--====================================================================

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

--====================================================================
-- Configuration
--====================================================================

local DEBUG_CONFIG = Config.Debug or {}
local ATTACHMENT_YAW_OVERRIDES = Config.AttachmentYawOverrides or {}

--====================================================================
-- State Management
--====================================================================

local Vehicle = nil
local StateContainer = nil
local MappedLights = {}
local GearValue = nil

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
	print(string.format("[ReverseLights][%s] %s", category, message))
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
	local attachmentName = "VOE_LightAttachment_Reverse"
	local attachment = part:FindFirstChild(attachmentName)
	if not attachment or not attachment:IsA("Attachment") then
		attachment = Instance.new("Attachment")
		attachment.Name = attachmentName
		attachment.Parent = part
	end
	local defaultYaw = 180
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
	spot.Brightness = Config.Lights.Reverse.Brightness or 1
	spot.Range = Config.Lights.Reverse.Range or 22
	spot.Angle = Config.Lights.Reverse.Angle or 70
	spot.Color = Config.Lights[profileName].Color or Color3.fromRGB(255, 255, 255)
	spot.Shadows = Config.Lights[profileName].Shadows ~= false
	spot.Enabled = false
	return spot
end

local function mapLightsByTag(tagName, profileName)
	if not tagName or tagName == "" then return {} end
	local list = {}
	for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
		local part = resolveBasePart(inst)
		if part and Vehicle and part:IsDescendantOf(Vehicle) then
			local spot = ensureSpotlight(part, Config.Lights[profileName], profileName)
			table.insert(list, {
				Spot = spot,
				Part = part,
				Profile = Config.Lights[profileName],
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
		Reverse = mapLightsByTag(Tags.Required[1], "Reverse"),
		ReflectorReverse = mapLightsByTag(Tags.Required[2], "ReflectorReverse"),
	}
end

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

local function applyReverseLightState()
	local reverseOn = false
	if GearValue then
		reverseOn = (GearValue.Value or 0) == -1
	end
	if reverseOn then
		enableLights(MappedLights.Reverse)
		enableLights(MappedLights.ReflectorReverse)
	else
		disableLights(MappedLights.Reverse)
		disableLights(MappedLights.ReflectorReverse)
	end
end

local function startup()
	-- Look for Values folder directly in parent (A-Chassis Interface)
	local valuesFolder = script.Parent:FindFirstChild("Values")
	
	-- Find the vehicle via Car ObjectValue
	local carValue = script.Parent:FindFirstChild("Car")
	if carValue and carValue:IsA("ObjectValue") and carValue.Value then
		Vehicle = carValue.Value
	elseif script.Parent:FindFirstChild("Car") then
		-- Car value might not be set yet, wait for it
		carValue = script.Parent:WaitForChild("Car", 5)
		if carValue and carValue:IsA("ObjectValue") then
			Vehicle = carValue.Value
		end
	end
	
	if not Vehicle then
		warn("[ReverseLights] Could not find vehicle model")
		return
	end

	StateContainer = valuesFolder or Vehicle
	setupPluginSounds(Vehicle)
	
	if not StateContainer then
		warn("[ReverseLights] Could not resolve state container")
		return
	end

	setupLightMapping()
	GearValue = StateContainer:FindFirstChild("Gear")
	if GearValue then
		GearValue.Changed:Connect(applyReverseLightState)
	else
		warn("[ReverseLights] Could not find Gear value in " .. StateContainer:GetFullName())
	end
	applyReverseLightState()
end

startup()
