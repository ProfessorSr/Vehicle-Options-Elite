 
-- V O E   P L U G I N S • Damage
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles vehicle damage calculation, visual damage, and part detachment
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)
-- - Damage is stored per-part via attributes and state values
-- - Parts become detachable when their HitPoints reach zero

-- - Clean, modular, no deprecated code

--====================================================================
-- Module Requires
--====================================================================

local Config = require(script:WaitForChild("Config"))
local Tags = require(script:WaitForChild("Tags"))
local PluginSounds = require(script:WaitForChild("Sounds"))

if Config and Config.Enabled == false then
	warn("[Damage] Plugin disabled via config")
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
local DAMAGE_ZONES = Config.DamageZones or {}
local VISUAL_STAGES = Config.VisualStages or {}
local DETACH_SETTINGS = Config.DetachSettings or {}

--====================================================================
-- State Management
--====================================================================

local Vehicle = nil
local StateValues = {}
local StateContainer = nil
local Items = {} -- Stores per-part damage data: {Part, HitPoints, MaxHitPoints, Zone, Detached, Originals}
local DamageLog = {} -- Stores recent impact events for persistence
local ImpactCooldowns = {} -- Per-part cooldown tracking

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
			voeState = vehicle:WaitForChild("VOE_State", 5)
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
	print(string.format("[Damage][%s] %s", category, message))
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
	value:SetAttribute("VOE_Owner", "Damage")
	value:SetAttribute("VOE_Type", "State")
	if className == "BoolValue" then value.Value = defaultValue or false
	elseif className == "IntValue" then value.Value = defaultValue or 0
	elseif className == "NumberValue" then value.Value = defaultValue or 0
	elseif className == "StringValue" then value.Value = defaultValue or "" end
	return value
end

local function initializeStateValues()
	if not StateContainer then return end
	StateValues.TotalDamage = ensureStateValue(StateContainer, "TotalDamage", "NumberValue", 0)
	StateValues.VehicleDestroyed = ensureStateValue(StateContainer, "VehicleDestroyed", "BoolValue", false)
	StateValues.PartsDetached = ensureStateValue(StateContainer, "PartsDetached", "IntValue", 0)
	StateValues.DamageLog = ensureStateValue(StateContainer, "DamageLog", "StringValue", "[]")
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
-- Damage Zone Resolution
--====================================================================

local function getZoneConfig(zoneName)
	return DAMAGE_ZONES[zoneName] or DAMAGE_ZONES["Default"] or {}
end

local function getPartZone(part)
	-- Check if part has an explicit zone attribute
	local zoneAttr = part:GetAttribute(Tags.Optional.ZoneAttribute)
	if zoneAttr and type(zoneAttr) == "string" and zoneAttr ~= "" then
		return zoneAttr
	end
	-- Check tags on the part to determine zone
	for zoneName, _ in pairs(DAMAGE_ZONES) do
		local zoneTag = Tags.Required["Damage_" .. zoneName .. "_Part"]
		if zoneTag and CollectionService:HasTag(part, zoneTag) then
			return zoneName
		end
	end
	return "Default"
end

--====================================================================
-- Damage Calculation
--====================================================================

local function calculateImpactDamage(impactSpeed, otherPart)
	-- Base damage from impact speed (studs/sec)
	local speed = math.abs(impactSpeed or 0)
	local baseDamage = speed * (Config.DamageMultiplier or 1.0)

	-- Check if the other part is another vehicle or heavy object
	local massMultiplier = 1.0
	if otherPart and otherPart:IsA("BasePart") then
		local otherMass = otherPart.AssemblyMass
		if otherMass and otherMass > 500 then
			massMultiplier = Config.HeavyObjectMultiplier or 2.0
		end
	end

	return math.clamp(baseDamage * massMultiplier, Config.MinimumDamage or 1, Config.MaximumDamage or 100)
end

local function getHitPoints(part, zoneName)
	-- Check part attribute override first
	local hpAttr = tonumber(part:GetAttribute(Tags.Optional.HitPointsAttribute))
	if hpAttr and hpAttr > 0 then
		return hpAttr
	end
	-- Fall back to zone config
	local zoneConfig = getZoneConfig(zoneName)
	return tonumber(zoneConfig.HitPoints) or tonumber(Config.DefaultHitPoints) or 100
end

--====================================================================
-- Visual Damage System
--====================================================================

local function getVisualStage(damagePercent)
	-- damagePercent: 0 = pristine, 1 = fully damaged
	for i = #VISUAL_STAGES, 1, -1 do
		local stage = VISUAL_STAGES[i]
		if damagePercent >= (stage.Threshold or 0) then
			return stage
		end
	end
	return VISUAL_STAGES[1]
end

local function applyVisualDamage(item)
	if not item or not item.Part or not item.Part.Parent then return end

	local part = item.Part
	local damagePercent = 1 - (item.HitPoints / item.MaxHitPoints)
	local stage = getVisualStage(damagePercent)

	-- Apply color shift (darkening / discoloration)
	if stage.ColorShift then
		local origColor = item.Originals.Color
		local shift = stage.ColorShift
		part.Color = Color3.new(
			math.clamp(origColor.R + (shift.R or 0), 0, 1),
			math.clamp(origColor.G + (shift.G or 0), 0, 1),
			math.clamp(origColor.B + (shift.B or 0), 0, 1)
		)
	end

	-- Apply material change
	if stage.Material then
		part.Material = stage.Material
	end

	-- Apply transparency (for glass / broken parts)
	if stage.Transparency ~= nil then
		part.Transparency = math.max(item.Originals.Transparency, stage.Transparency)
	end

	-- Apply reflectance change
	if stage.Reflectance ~= nil then
		part.Reflectance = stage.Reflectance
	end

	-- Apply surface deformation via size distortion
	if stage.DeformScale and not item.Detached then
		local deform = stage.DeformScale
		local origSize = item.Originals.Size
		part.Size = Vector3.new(
			origSize.X * (1 + (deform.X or 0) * damagePercent),
			origSize.Y * (1 + (deform.Y or 0) * damagePercent),
			origSize.Z * (1 + (deform.Z or 0) * damagePercent)
		)
	end

	-- Store current damage percent on the part as an attribute for external reading
	part:SetAttribute(Tags.Optional.DamagePercentAttribute, damagePercent)
	part:SetAttribute(Tags.Optional.HitPointsAttribute, item.HitPoints)
end

--====================================================================
-- Part Detachment System
--====================================================================

local function detachPart(item)
	if not item or item.Detached then return end
	if not item.Part or not item.Part.Parent then return end

	local part = item.Part
	item.Detached = true

	-- Remove all welds connecting this part to the vehicle
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("WeldConstraint") or child:IsA("Weld") or child:IsA("Motor6D") then
			child.Parent = nil
		end
	end

	-- Also check parent for welds referencing this part
	local parentModel = part.Parent
	if parentModel then
		for _, child in ipairs(parentModel:GetChildren()) do
			if child:IsA("WeldConstraint") then
				if child.Part0 == part or child.Part1 == part then
					child.Parent = nil
				end
			end
		end
	end

	-- Unanchor the part so it falls / tumbles away
	part.Anchored = false

	-- Apply a small random velocity for visual effect
	if part:IsA("BasePart") then
		part.AssemblyLinearVelocity = Vector3.new(
			math.random(-5, 5),
			math.random(2, 8),
			math.random(-5, 5)
		)
		part.AssemblyAngularVelocity = Vector3.new(
			math.random(-3, 3),
			math.random(-3, 3),
			math.random(-3, 3)
		)
	end

	-- Move detached part to workspace root so it persists as debris
	part.Parent = game.Workspace

	-- Schedule cleanup of debris after configured time
	local cleanupDelay = DETACH_SETTINGS.DebrisLifetime or 30
	task.delay(cleanupDelay, function()
		if part and part.Parent then
			part.Parent = nil
		end
	end)

	-- Play detachment sound
	local body = Vehicle and Vehicle:FindFirstChild("Body")
	if body then
		local sounds = body:FindFirstChild("Sounds")
		if sounds then
			local snd = sounds:FindFirstChild("PartDetach")
			if snd and snd:IsA("Sound") then
				snd:Play()
			end
		end
	end

	-- Update state
	if StateValues.PartsDetached then
		StateValues.PartsDetached.Value = StateValues.PartsDetached.Value + 1
	end

	debugLog("Detach", "Part detached: " .. part.Name)
end

--====================================================================
-- Impact Handler
--====================================================================

local function onPartTouched(item, otherPart)
	if item.Detached then return end
	if not item.Part or not item.Part.Parent then return end

	-- Cooldown check to prevent rapid-fire damage
	local now = tick()
	local lastImpact = ImpactCooldowns[item.Part] or 0
	local cooldown = Config.ImpactCooldown or 0.1
	if (now - lastImpact) < cooldown then return end
	ImpactCooldowns[item.Part] = now

	-- Calculate impact speed from relative velocity
	local part = item.Part
	local otherVelocity = Vector3.zero
	if otherPart:IsA("BasePart") then
		otherVelocity = otherPart.AssemblyLinearVelocity
	end
	local relativeVelocity = (part.AssemblyLinearVelocity - otherVelocity)
	local impactSpeed = relativeVelocity.Magnitude

	-- Skip if impact is too weak
	local minSpeed = Config.MinimumImpactSpeed or 5
	if impactSpeed < minSpeed then return end

	-- Calculate damage
	local damage = calculateImpactDamage(impactSpeed, otherPart)

	-- Apply damage to hit points
	item.HitPoints = math.max(0, item.HitPoints - damage)

	-- Play impact sound based on severity
	local body = Vehicle and Vehicle:FindFirstChild("Body")
	if body then
		local sounds = body:FindFirstChild("Sounds")
		if sounds then
			local impactSpeedNorm = math.clamp(impactSpeed / 100, 0, 1)
			if impactSpeedNorm > 0.7 then
				local snd = sounds:FindFirstChild("HeavyImpact")
				if snd and snd:IsA("Sound") then snd:Play() end
			elseif impactSpeedNorm > 0.3 then
				local snd = sounds:FindFirstChild("MediumImpact")
				if snd and snd:IsA("Sound") then snd:Play() end
			else
				local snd = sounds:FindFirstChild("LightImpact")
				if snd and snd:IsA("Sound") then snd:Play() end
			end
		end
	end

	-- Update visual damage
	applyVisualDamage(item)

	-- Update total damage state
	if StateValues.TotalDamage then
		StateValues.TotalDamage.Value = StateValues.TotalDamage.Value + damage
	end

	-- Log the impact
	local logEntry = {
		Part = part.Name,
		Damage = damage,
		Speed = impactSpeed,
		Timestamp = now,
		RemainingHP = item.HitPoints,
	}
	table.insert(DamageLog, logEntry)

	-- Trim log to max entries
	local maxLog = Config.MaxDamageLogEntries or 100
	while #DamageLog > maxLog do
		table.remove(DamageLog, 1)
	end

	-- Persist damage log to state value
	if StateValues.DamageLog then
		local serialized = {}
		for _, entry in ipairs(DamageLog) do
			table.insert(serialized, string.format("%s:%d:%d", entry.Part, entry.Damage, entry.RemainingHP))
		end
		StateValues.DamageLog.Value = game:GetService("HttpService"):JSONEncode(serialized)
	end

	debugLog("Impact", string.format("%s: -%d HP (%d/%d) Speed=%.1f",
		part.Name, damage, item.HitPoints, item.MaxHitPoints, impactSpeed))

	-- Check for detachment
	if item.HitPoints <= 0 and DETACH_SETTINGS.Enabled ~= false then
		local zoneConfig = getZoneConfig(item.Zone)
		if zoneConfig.CanDetach ~= false then
			detachPart(item)
		end
	end

	-- Check if vehicle is destroyed
	if StateValues.VehicleDestroyed and not StateValues.VehicleDestroyed.Value then
		local totalParts = #Items
		local detachedParts = 0
		local zeroHPParts = 0
		for _, it in ipairs(Items) do
			if it.Detached then
				detachedParts = detachedParts + 1
			elseif it.HitPoints <= 0 then
				zeroHPParts = zeroHPParts + 1
			end
		end
		local destroyedThreshold = Config.DestroyedThreshold or 0.75
		if totalParts > 0 and (detachedParts + zeroHPParts) / totalParts >= destroyedThreshold then
			StateValues.VehicleDestroyed.Value = true
			debugLog("Status", "Vehicle destroyed!")
		end
	end
end

--====================================================================
-- Setup
--====================================================================

local function setupDamageableParts()
	if not Vehicle then return end
	Items = {}

	-- Collect all parts tagged as damageable
	local damageableParts = collectTaggedParts(Tags.Required.DamageablePart)

	-- Also collect zone-specific parts
	for zoneName, _ in pairs(DAMAGE_ZONES) do
		local zoneTag = Tags.Required["Damage_" .. zoneName .. "_Part"]
		if zoneTag then
			local zoneParts = collectTaggedParts(zoneTag)
			for _, p in ipairs(zoneParts) do
				-- Avoid duplicates
				local alreadyAdded = false
				for _, existing in ipairs(damageableParts) do
					if existing == p then alreadyAdded = true; break end
				end
				if not alreadyAdded then
					table.insert(damageableParts, p)
				end
			end
		end
	end

	-- If no tagged parts found, auto-discover body parts
	if #damageableParts == 0 and Config.AutoDiscoverParts ~= false then
		debugLog("Setup", "No tagged damageable parts found, auto-discovering body parts")
		local body = Vehicle:FindFirstChild("Body")
		if body then
			for _, descendant in ipairs(body:GetDescendants()) do
				if descendant:IsA("BasePart") and not descendant:IsA("Seat") then
					table.insert(damageableParts, descendant)
				end
			end
		end
	end

	debugLog("Setup", "Found " .. #damageableParts .. " damageable parts")

	-- Initialize each part
	for _, part in ipairs(damageableParts) do
		local zoneName = getPartZone(part)
		local maxHP = getHitPoints(part, zoneName)

		-- Check for existing damage (from previous session via attributes)
		local existingHP = tonumber(part:GetAttribute(Tags.Optional.HitPointsAttribute))
		local currentHP = existingHP and math.clamp(existingHP, 0, maxHP) or maxHP

		local item = {
			Part = part,
			HitPoints = currentHP,
			MaxHitPoints = maxHP,
			Zone = zoneName,
			Detached = false,
			Originals = {
				Color = part.Color,
				Material = part.Material,
				Transparency = part.Transparency,
				Reflectance = part.Reflectance,
				Size = part.Size,
			},
		}

		table.insert(Items, item)

		-- Connect touch event for this part
		part.Touched:Connect(function(otherPart)
			onPartTouched(item, otherPart)
		end)

		-- Apply any existing visual damage from restored state
		if currentHP < maxHP then
			applyVisualDamage(item)
		end

		-- Store initial attributes for persistence
		part:SetAttribute(Tags.Optional.HitPointsAttribute, currentHP)
		part:SetAttribute(Tags.Optional.MaxHitPointsAttribute, maxHP)
		part:SetAttribute(Tags.Optional.ZoneAttribute, zoneName)
	end
end

--====================================================================
-- Damage Persistence (Save/Load)
--====================================================================

local function saveDamageState()
	if not Vehicle then return end

	-- Save damage to part attributes (persistent across sessions when model is saved)
	for _, item in ipairs(Items) do
		if item.Part and item.Part.Parent then
			item.Part:SetAttribute(Tags.Optional.HitPointsAttribute, item.HitPoints)
			item.Part:SetAttribute(Tags.Optional.MaxHitPointsAttribute, item.MaxHitPoints)
			item.Part:SetAttribute(Tags.Optional.ZoneAttribute, item.Zone)
			item.Part:SetAttribute(Tags.Optional.DamagePercentAttribute, 1 - (item.HitPoints / item.MaxHitPoints))
		end
	end

	debugLog("Persistence", "Damage state saved to part attributes")
end

local function loadDamageState()
	if not Vehicle then return end

	-- Damage is loaded during setupDamageableParts via attribute reads
	-- This function can be extended to load from DataStoreService
	debugLog("Persistence", "Damage state loaded from part attributes")
end

--====================================================================
-- Repair System
--====================================================================

local function repairPart(item, amount)
	if not item or item.Detached then return end
	if not item.Part or not item.Part.Parent then return end

	local repairAmount = amount or item.MaxHitPoints
	item.HitPoints = math.min(item.MaxHitPoints, item.HitPoints + repairAmount)

	-- Restore visuals if fully repaired
	if item.HitPoints >= item.MaxHitPoints then
		item.HitPoints = item.MaxHitPoints
		local part = item.Part
		part.Color = item.Originals.Color
		part.Material = item.Originals.Material
		part.Transparency = item.Originals.Transparency
		part.Reflectance = item.Originals.Reflectance
		part.Size = item.Originals.Size
		part:SetAttribute(Tags.Optional.DamagePercentAttribute, 0)
		part:SetAttribute(Tags.Optional.HitPointsAttribute, item.MaxHitPoints)
	else
		applyVisualDamage(item)
	end

	debugLog("Repair", item.Part.Name .. " repaired to " .. item.HitPoints .. "/" .. item.MaxHitPoints)
end

local function repairAll(amount)
	for _, item in ipairs(Items) do
		repairPart(item, amount)
	end
	if StateValues.TotalDamage then
		StateValues.TotalDamage.Value = 0
	end
	if StateValues.VehicleDestroyed then
		StateValues.VehicleDestroyed.Value = false
	end
	debugLog("Repair", "All parts repaired")
end

--====================================================================
-- Keybind Handling
--====================================================================

local function handleKeybind(input, gameProcessed)
	if gameProcessed then return end
	local keyCode = input.KeyCode
	local keybinds = Config.Keybinds or {}

	-- Repair all keybind
	if keyCode == (keybinds.RepairAll or Enum.KeyCode.Unknown) then
		repairAll()
		if DEBUG_CONFIG.LogKeybinds ~= false then
			debugLog("Input", "Repair all triggered")
		end
	end

	-- Toggle damage debug overlay
	if keyCode == (keybinds.ToggleDebug or Enum.KeyCode.Unknown) then
		DEBUG_CONFIG.Enabled = not DEBUG_CONFIG.Enabled
		if DEBUG_CONFIG.LogKeybinds ~= false then
			debugLog("Input", "Debug overlay " .. (DEBUG_CONFIG.Enabled and "ON" or "OFF"))
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
		warn("[Damage] Could not find vehicle model")
		return
	end

	initializeStateValues()
	loadDamageState()
	setupDamageableParts()

	-- Connect state change listeners
	if StateValues.VehicleDestroyed then
		StateValues.VehicleDestroyed.Changed:Connect(function()
			debugLog("Status", "Vehicle destroyed state: " .. tostring(StateValues.VehicleDestroyed.Value))
		end)
	end

	if UserInputService then
		UserInputService.InputBegan:Connect(handleKeybind)
	end

	-- Periodic save of damage state
	local saveInterval = Config.SaveInterval or 10
	task.spawn(function()
		while Vehicle and Vehicle.Parent do
			task.wait(saveInterval)
			saveDamageState()
		end
	end)

	-- Handle parts added during gameplay
	if Vehicle then
		local body = Vehicle:FindFirstChild("Body")
		if body then
			body.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("BasePart") and CollectionService:HasTag(descendant, Tags.Required.DamageablePart) then
					local zoneName = getPartZone(descendant)
					local maxHP = getHitPoints(descendant, zoneName)
					local item = {
						Part = descendant,
						HitPoints = maxHP,
						MaxHitPoints = maxHP,
						Zone = zoneName,
						Detached = false,
						Originals = {
							Color = descendant.Color,
							Material = descendant.Material,
							Transparency = descendant.Transparency,
							Reflectance = descendant.Reflectance,
							Size = descendant.Size,
						},
					}
					table.insert(Items, item)
					descendant.Touched:Connect(function(otherPart)
						onPartTouched(item, otherPart)
					end)
					descendant:SetAttribute(Tags.Optional.HitPointsAttribute, maxHP)
					descendant:SetAttribute(Tags.Optional.MaxHitPointsAttribute, maxHP)
					descendant:SetAttribute(Tags.Optional.ZoneAttribute, zoneName)
					debugLog("Setup", "Late-added part: " .. descendant.Name)
				end
			end)
		end
	end

	debugLog("Startup", "Damage plugin initialized successfully")
end

startup()