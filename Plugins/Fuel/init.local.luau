 
-- V O E   P L U G I N S • Fuel
-- DATE (UTC):
--
-- DESCRIPTION:
-- Manages fuel consumption, refueling, and empty behavior
-- Now with DataStore persistence via server-side FuelPersistence script.
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)
-- - Clean, modular, no deprecated code
-- - Fuel syncs to server every 5 seconds and on refuel for DataStore persistence

--====================================================================
-- Module Requires
--====================================================================

local FuelConfig = require(script:WaitForChild("Config"))
local FuelTags = require(script:WaitForChild("Tags"))
local PluginSounds = require(script:WaitForChild("Sounds"))

if FuelConfig and FuelConfig.Enabled == false then
	warn("[Fuel] Plugin disabled via config")
	return
end

--====================================================================
-- Services
--====================================================================

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Fuel sync interval: how often (in seconds) the client sends fuel updates to the server.
local FUEL_SYNC_INTERVAL = 5

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
			-- Wait briefly for rig bootstrap to create VOE_State (race can occur during spawn)
			voeState = vehicle:FindFirstChild("VOE_State") or vehicle:WaitForChild("VOE_State", 5)
		end
		if voeState then
			return vehicle, voeState, pluginContainer, valuesFolder
		end
		-- Fallback to Values folder (legacy)
		return vehicle, valuesFolder, pluginContainer, valuesFolder
	end
	return nil, valuesFolder, pluginContainer, valuesFolder
end

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
	print(string.format("[Fuel][%s] %s", category, message))
end

local function ensureValue(parent: Instance, name: string, className: string)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local value = Instance.new(className)
	value.Name = name
	value.Parent = parent
	value:SetAttribute("VOE_Owner", "Fuel")
	value:SetAttribute("VOE_Type", "State")
	return value
end

--====================================================================
-- Plugin Module
--====================================================================

local Fuel = {}
Fuel.__index = Fuel

function Fuel.getPluginInfo()
	return {
		Name = FuelTags.Name,
		Actions = {
			FuelConfig.Actions.RefillFuel,
			FuelConfig.Actions.SetFuelGallons,
			FuelConfig.Actions.AddFuelGallons,
		},
		StateValues = {
			FuelLevel = {ClassName = "NumberValue", Default = 100},
			FuelGallons = {ClassName = "NumberValue", Default = 0},
			FuelCapacityGallons = {ClassName = "NumberValue", Default = FuelConfig.MaxGallons},
			FuelEmpty = {ClassName = "BoolValue", Default = false},
			FuelLimpMode = {ClassName = "BoolValue", Default = false},
		},
		ClickInteractions = {
			{Tag = FuelTags.Click.PumpRefill, Role = "FuelPumpRefill", Action = FuelConfig.Actions.RefillFuel},
			{Tag = FuelTags.Click.PumpAdd, Role = "FuelPumpAdd", Action = FuelConfig.Actions.AddFuelGallons, Payload = FuelConfig.RefuelGallonsPerUse},
		},
	}
end

--====================================================================
-- Factory Function
--====================================================================

function Fuel.create(context)
	local valuesFolder = context.Values
	if not valuesFolder and context.VehicleModel then
		valuesFolder = context.VehicleModel:FindFirstChild("Values")
		if not valuesFolder then
			valuesFolder = Instance.new("Folder")
			valuesFolder.Name = "Values"
			valuesFolder.Parent = context.VehicleModel
		end
	end

	-- Expose shared values from VOE_State / legacy Values folder.
	context.State.EngineOn = valuesFolder and valuesFolder:FindFirstChild("EngineOn") or nil
	context.State.Running = valuesFolder and valuesFolder:FindFirstChild("Running") or nil
	context.State.AccessoryOn = valuesFolder and valuesFolder:FindFirstChild("AccessoryOn") or nil
	context.State.IgnitionStarting = valuesFolder and valuesFolder:FindFirstChild("IgnitionStarting") or nil
	context.State.GasDoor = valuesFolder and valuesFolder:FindFirstChild("GasDoor") or nil
	context.State.FuelCap = valuesFolder and valuesFolder:FindFirstChild("FuelCap") or nil

	-- Look up IsOn (A-Chassis engine state) from the plugin container (A-Chassis Interface)
	local pluginContainer = context.PluginContainer
	if pluginContainer then
		local isOn = pluginContainer:FindFirstChild("IsOn")
		if isOn and isOn:IsA("BoolValue") then
			context.State.IsOn = isOn
		end
	end

	-- Look up Velocity from A-Chassis Values folder for speed calculation
	local achassisValues = context.AChassisValues
	if achassisValues then
		local velocity = achassisValues:FindFirstChild("Velocity")
		if velocity and velocity:IsA("Vector3Value") then
			context.State.Velocity = velocity
		end
	end

	return setmetatable({
		State = context.State,
		VehicleModel = context.VehicleModel,
		Seat = context.Seat,
		Config = FuelConfig,
		ValuesFolder = valuesFolder,
		_fuelSyncTimer = 0, -- tracks time since last server sync
	}, Fuel)
end

local function getEngineRunningState(state)
	if state.IsOn and state.IsOn:IsA("BoolValue") then
		return state.IsOn.Value
	end
	if state.EngineOn and state.EngineOn:IsA("BoolValue") then
		return state.EngineOn.Value
	end
	if state.Running and state.Running:IsA("BoolValue") then
		return state.Running.Value
	end
	return false
end

local function forceEngineOff(state)
	if state.IsOn and state.IsOn:IsA("BoolValue") then
		state.IsOn.Value = false
	end
	if state.EngineOn and state.EngineOn:IsA("BoolValue") then
		state.EngineOn.Value = false
	end
	if state.Running and state.Running:IsA("BoolValue") then
		state.Running.Value = false
	end
end

--====================================================================
-- Value Synchronization
--====================================================================

function Fuel:syncValuesFolder(capacity, gallons, percent, empty, limp)
	if not self.ValuesFolder then
		return
	end

	local fuelLevel = ensureValue(self.ValuesFolder, "FuelLevel", "NumberValue")
	local fuelGallons = ensureValue(self.ValuesFolder, "FuelGallons", "NumberValue")
	local fuelCapacity = ensureValue(self.ValuesFolder, "FuelCapacityGallons", "NumberValue")
	local fuelEmpty = ensureValue(self.ValuesFolder, "FuelEmpty", "BoolValue")
	local fuelLimpMode = ensureValue(self.ValuesFolder, "FuelLimpMode", "BoolValue")

	fuelLevel.Value = percent
	fuelGallons.Value = gallons
	fuelCapacity.Value = capacity
	fuelEmpty.Value = empty
	fuelLimpMode.Value = limp
end

function Fuel:syncOutputs()
	local capacity = self:getCapacityGallons()
	local gallons = math.clamp(tonumber(self.State.FuelGallons.Value) or 0, 0, capacity)
	local percent = math.clamp((gallons / capacity) * 100, 0, 100)
	local empty = gallons <= 0.0001

	self.State.FuelCapacityGallons.Value = capacity
	self.State.FuelGallons.Value = gallons
	self.State.FuelLevel.Value = percent
	self.State.FuelEmpty.Value = empty

	if self.VehicleModel then
		self.VehicleModel:SetAttribute("FuelCapacityGallons", capacity)
		self.VehicleModel:SetAttribute("FuelGallons", gallons)
		self.VehicleModel:SetAttribute("FuelLevel", percent)
		self.VehicleModel:SetAttribute("FuelEmpty", empty)
		self.VehicleModel:SetAttribute("FuelLimpMode", self.State.FuelLimpMode.Value == true)
	end

	self:syncValuesFolder(capacity, gallons, percent, empty, self.State.FuelLimpMode.Value == true)
end

--====================================================================
-- Capacity Functions
--====================================================================

function Fuel:getCapacityGallons()
	return math.max(0.01, tonumber(self.Config.MaxGallons) or 18)
end

function Fuel:getStartingGallons()
	local configured = tonumber(self.Config.StartingGallons)
	if configured == nil then
		configured = self:getCapacityGallons()
	end
	return math.clamp(configured, 0, self:getCapacityGallons())
end

--====================================================================
-- Server Sync (DataStore Persistence)
--====================================================================

function Fuel:syncFuelToServer()
	local fuelSyncRemote = ReplicatedStorage:FindFirstChild("FuelSyncRemote")
	if fuelSyncRemote then
		local vehicleId = self.VehicleModel and self.VehicleModel:GetAttribute("VehicleId") or "default"
		fuelSyncRemote:FireServer(vehicleId, tonumber(self.State.FuelGallons.Value) or 0)
	end
end

function Fuel:loadSavedFuelFromServer()
	local fuelLoadRemote = ReplicatedStorage:FindFirstChild("FuelLoadRemote")
	if not fuelLoadRemote then
		return nil
	end
	local vehicleId = self.VehicleModel and self.VehicleModel:GetAttribute("VehicleId") or "default"
	local ok, savedGallons = pcall(function()
		return fuelLoadRemote:InvokeServer(vehicleId)
	end)
	if ok and type(savedGallons) == "number" then
		return savedGallons
	end
	return nil
end

--====================================================================
-- Setup Functions
--====================================================================

function Fuel:setup()

	setupPluginSounds(self.VehicleModel)

	-- Try to load saved fuel from DataStore via server RemoteFunction.
	-- This replaces the old SavedFuelGallons attribute approach, which was
	-- unreliable because the server ModuleScript was never executed.
	local startGallons = self:getStartingGallons()
	local savedGallons = self:loadSavedFuelFromServer()
	if savedGallons ~= nil then
		startGallons = math.clamp(savedGallons, 0, self:getCapacityGallons())
		if FuelConfig.Debug and FuelConfig.Debug.Enabled then
			debugLog("Setup", "Loaded saved fuel from DataStore: " .. tostring(startGallons) .. " gallons")
		end
	end

	self.State.FuelGallons.Value = startGallons
	self.State.FuelLimpMode.Value = false
	self:syncOutputs()

	-- Immediately sync the starting fuel to the server so it has a baseline.
	self:syncFuelToServer()
end

--====================================================================
-- Refueling Functions
--====================================================================

function Fuel:canRefuel()
	if self.Config.AllowRefuelWhileEngineOn ~= true and getEngineRunningState(self.State) then
		return false
	end
	if self.Config.RequireGasDoorOpen ~= false and self.State.GasDoor and self.State.GasDoor.Value ~= true then
		return false
	end
	if self.Config.RequireFuelCapRemoved ~= false and self.State.FuelCap and self.State.FuelCap.Value ~= true then
		return false
	end
	if self.Config.RequireFuelCapRemoved ~= false and self.State.FuelCap == nil then
		return false
	end
	return true
end

--====================================================================
-- Empty Behavior Functions
--====================================================================

function Fuel:clearEmptyBehavior()
	self.State.FuelLimpMode.Value = false
	if self.VehicleModel then
		self.VehicleModel:SetAttribute("FuelLimpMode", false)
	end
	if self.ValuesFolder then
		ensureValue(self.ValuesFolder, "FuelLimpMode", "BoolValue").Value = false
	end
end

function Fuel:applyEmptyBehavior()
	local empty = self.State.FuelEmpty.Value == true
	if not empty then
		self:clearEmptyBehavior()
		return
	end

	local mode = tostring(self.Config.EmptyBehavior or "Shutoff")
	if string.lower(mode) == "limp" then
		self.State.FuelLimpMode.Value = true
		if self.VehicleModel then
			self.VehicleModel:SetAttribute("FuelLimpMode", true)
		end
		if self.ValuesFolder then
			ensureValue(self.ValuesFolder, "FuelLimpMode", "BoolValue").Value = true
		end
	else
		self:clearEmptyBehavior()
		forceEngineOff(self.State)
		if self.State.IgnitionStarting then
			self.State.IgnitionStarting.Value = false
		end
		if self.State.AccessoryOn and self.Config.KeepAccessoryOnWhenEmpty ~= true then
			self.State.AccessoryOn.Value = false
		end
	end
end

--====================================================================
-- Action Handling
--====================================================================

function Fuel:handleAction(action, payload)
	if action == self.Config.Actions.RefillFuel then
		if not self:canRefuel() then
			return false
		end
		self.State.FuelGallons.Value = self:getCapacityGallons()
	elseif action == self.Config.Actions.SetFuelGallons then
		self.State.FuelGallons.Value = math.clamp(tonumber(payload) or 0, 0, self:getCapacityGallons())
	elseif action == self.Config.Actions.AddFuelGallons then
		if not self:canRefuel() then
			return false
		end
		self.State.FuelGallons.Value = math.clamp((tonumber(self.State.FuelGallons.Value) or 0) + (tonumber(payload) or 0), 0, self:getCapacityGallons())
	else
		return false
	end
	self:syncOutputs()
	self:applyEmptyBehavior()

	-- Sync fuel to server immediately after a refuel action
	self:syncFuelToServer()

	return true
end

--====================================================================
-- Update Loop
--====================================================================

function Fuel:update(dt)
	if self.Config.Enabled == false or not (self.State and self.State.FuelGallons and self.State.FuelLevel) then
		return
	end
	local capacity = self:getCapacityGallons()

	-- Debug override: set a "DebugFuelPercent" number attribute (0–100) on the car model in Studio
	-- to lock fuel to a specific level for gauge testing. Remove the attribute to resume normal behaviour.
	if self.VehicleModel then
		local debugPct = self.VehicleModel:GetAttribute("DebugFuelPercent")
		if type(debugPct) == "number" then
			local pct = math.clamp(debugPct, 0, 100)
			self.State.FuelGallons.Value = (pct / 100) * capacity
			self:syncOutputs()
			return
		end
	end
	self.State.FuelCapacityGallons.Value = capacity
	if not getEngineRunningState(self.State) then
		self:syncOutputs()
		return
	end
	local throttle = self.Seat and self.Seat.ThrottleFloat or 0
	local speed = 0
	if self.State.Velocity and self.State.Velocity:IsA("Vector3Value") then
		speed = self.State.Velocity.Value.Magnitude
	end
	local throttleNorm = math.clamp(math.abs(tonumber(throttle) or 0), 0, 1)
	local speedNorm = math.clamp(speed / 140, 0, 1)
	local burnRatePercent = (tonumber(self.Config.BurnRateIdlePercent) or 0.0015) + (tonumber(self.Config.BurnRateLoadPercent) or 0.015) * math.max(throttleNorm, speedNorm)
	local burnGallons = capacity * (burnRatePercent / 100) * dt
	self.State.FuelGallons.Value = math.clamp((tonumber(self.State.FuelGallons.Value) or 0) - burnGallons, 0, capacity)
	self:syncOutputs()
	self:applyEmptyBehavior()

	-- Periodically sync fuel level to the server for DataStore persistence
	self._fuelSyncTimer = self._fuelSyncTimer + dt
	if self._fuelSyncTimer >= FUEL_SYNC_INTERVAL then
		self._fuelSyncTimer = 0
		self:syncFuelToServer()
	end
end

--====================================================================
-- Config Accessor
--====================================================================

function Fuel.getConfig()
	return FuelConfig
end

--====================================================================
-- Initialization
--====================================================================

task.defer(function()
	local vehicle, valuesFolder, pluginContainer, achassisValues = findRuntimeCarAndValues()
	if not vehicle then
		warn("[Fuel] Could not find vehicle model")
		return
	end

	local context = {
		VehicleModel = vehicle,
		Values = valuesFolder,
		Seat = vehicle:FindFirstChild("DriveSeat"),
		State = {},
		PluginContainer = pluginContainer,
		AChassisValues = achassisValues,
	}

	-- Initialize state values
	for stateName, spec in pairs(Fuel.getPluginInfo().StateValues) do
		local existing = valuesFolder:FindFirstChild(stateName)
		if not existing then
			local value = Instance.new(spec.ClassName)
			value.Name = stateName
			value.Value = spec.Default
			value.Parent = valuesFolder
		end
		context.State[stateName] = valuesFolder:FindFirstChild(stateName)
	end

	local plugin = Fuel.create(context)
	plugin:setup()

	RunService.Heartbeat:Connect(function(dt)
		plugin:update(dt)
	end)
	end)

return Fuel
