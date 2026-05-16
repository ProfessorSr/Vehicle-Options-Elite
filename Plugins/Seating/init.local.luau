 
-- V O E   P L U G I N S • Seating
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles seat access, entry/exit authorization, and seat locking
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
	warn("[Seating] Plugin disabled via config")
	return
end

--====================================================================
-- Services
--====================================================================

local RunService = game:GetService("RunService")
local UserInputService = RunService:IsClient() and game:GetService("UserInputService") or nil

--====================================================================
-- Configuration
--====================================================================

local DEBUG_CONFIG = Config.Debug or {}

--====================================================================
-- State Management
--====================================================================

local Vehicle = nil
local StateValues = {}
local StateContainer = nil
local DoorStateValues = {}
-- SeatAuthorizations removed - now handled server-side

--====================================================================
-- Context Resolution
--====================================================================

local function findRuntimeCarAndValues()
	local pluginContainer = script.Parent
	local valuesFolder = pluginContainer:FindFirstChild("Values")
	
	-- Look for Car ObjectValue in A-Chassis Interface (sibling of Plugins folder)
	local chassisInterface = pluginContainer.Parent and pluginContainer.Parent:FindFirstChild("A-Chassis Interface")
	local carValue = chassisInterface and chassisInterface:FindFirstChild("Car")
	
	-- Fallback: check pluginContainer directly (legacy)
	if not carValue then
		carValue = pluginContainer:FindFirstChild("Car")
	end

	if carValue and carValue:IsA("ObjectValue") and carValue.Value and carValue.Value:IsA("Model") then
		return carValue.Value, valuesFolder
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
	print(string.format("[Seating][%s] %s", category, message))
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
	value:SetAttribute("VOE_Owner", "Seating")
	value:SetAttribute("VOE_Type", "State")
	if className == "BoolValue" then value.Value = defaultValue or false end
	return value
end

local function initializeStateValues()
	if not StateContainer then return end
	-- Seat lock state
	StateValues.SeatLocked = ensureStateValue(StateContainer, "SeatLocked", "BoolValue", false)
end

local function findDoorStateValues()
	if not StateContainer then return end
	local values = StateContainer
	if not StateContainer:IsA("Folder") then
		values = StateContainer:FindFirstChild("Values")
	end
	if not values then return end
	
	for _, name in ipairs({"DoorFL", "DoorFR", "DoorRL", "DoorRR", "DoorSL", "DoorSR"}) do
		local stateValue = values:FindFirstChild(name)
		if stateValue and stateValue:IsA("BoolValue") then
			DoorStateValues[name] = stateValue
		end
	end
end

--====================================================================
-- Seat Authorization Functions
-- NOTE: Seat authorization is now handled server-side by VehicleSeatDoorLock
--====================================================================

-- Kept for reference, but authorization is now server-side
local function getSeatForDoor(doorRole)
	local seatAccess = Config.SeatAccess or {}
	local seatByRole = seatAccess.SeatByRole or {}
	return seatByRole[doorRole]
end

local function getDoorForSeat(seatName)
	local seatAccess = Config.SeatAccess or {}
	local roleBySeatName = seatAccess.RoleBySeatName or {}
	return roleBySeatName[seatName]
end

local function getExitDirection(doorRole)
	local seatAccess = Config.SeatAccess or {}
	local exitDir = seatAccess.ExitDirectionByRole or {}
	return exitDir[doorRole] or 1
end

local function isDoorOpen(doorRole)
	local stateValue = DoorStateValues[doorRole]
	return stateValue and stateValue.Value or false
end

--====================================================================
-- Seat Lock Functions
-- NOTE: Seat locking is kept but door-based entry/exit is handled server-side
--====================================================================

local function isSeatLocked(seatName)
	local seatLock = Config.SeatLock or {}
	if not seatLock.Enabled then return false end
	
	-- Check global lock
	if StateValues.SeatLocked and StateValues.SeatLocked.Value then
		return true
	end
	
	-- Check individual seat locks
	local lockedSeats = seatLock.LockedSeats or {}
	for _, lockedSeat in ipairs(lockedSeats) do
		if lockedSeat == seatName then
			return true
		end
	end
	
	return false
end

--====================================================================
-- Actions
--====================================================================

local function toggleSeatLock()
	if StateValues.SeatLocked then
		StateValues.SeatLocked.Value = not StateValues.SeatLocked.Value
	end
end

--====================================================================
-- Keybind Handling
--====================================================================

local function handleKeybind(input, gameProcessed)
	if gameProcessed then return end
	local keyCode = input.KeyCode
	local keybinds = Config.Keybinds or {}
	
	if keyCode == (keybinds.ToggleSeatLock or Enum.KeyCode.Unknown) then
		toggleSeatLock()
		if DEBUG_CONFIG.LogKeybinds ~= false then
			debugLog("Input", "Seat lock " .. (StateValues.SeatLocked and StateValues.SeatLocked.Value and "ON" or "OFF"))
		end
	end
end

--====================================================================
-- Startup
--====================================================================

local function startup()
	local runtimeCar, runtimeValues = findRuntimeCarAndValues()
	Vehicle = runtimeCar
	StateContainer = runtimeValues or Vehicle
	setupPluginSounds(Vehicle)
	
	if not Vehicle then
		warn("[Seating] Could not find vehicle model")
		return
	end
	
	initializeStateValues()
	findDoorStateValues()
	
	if UserInputService then
		UserInputService.InputBegan:Connect(handleKeybind)
	end
	
	debugLog("Startup", "Seating plugin initialized successfully")
end

startup()