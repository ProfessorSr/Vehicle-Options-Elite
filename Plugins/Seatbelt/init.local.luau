 
-- V O E   P L U G I N S • Seatbelt
-- DATE (UTC):
--
-- DESCRIPTION:
-- Manages seatbelt state for driver and front passenger
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)

-- - Clean, modular, no deprecated code

--====================================================================
-- Module Requires
--====================================================================

local SeatbeltConfig = require(script:WaitForChild("Config"))
local SeatbeltTags = require(script:WaitForChild("Tags"))
local PluginSounds = require(script:WaitForChild("Sounds"))

if SeatbeltConfig and SeatbeltConfig.Enabled == false then
	warn("[Seatbelt] Plugin disabled via config")
	return
end

--====================================================================
-- Context Resolution
--====================================================================

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
end

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

--====================================================================
-- Plugin Module
--====================================================================

local Seatbelt = {}
Seatbelt.__index = Seatbelt

function Seatbelt.getPluginInfo()
	return {
		Name = SeatbeltTags.Name,
		Actions = {
			SeatbeltConfig.Actions.ToggleSeatbelt,
		},
		Keybinds = SeatbeltConfig.Keybinds,
		StateValues = {
			DriverSeatbelt = {ClassName = "BoolValue", Default = false},
			FrontPassengerSeatbelt = {ClassName = "BoolValue", Default = false},
			SeatbeltChime = {ClassName = "BoolValue", Default = false},
		},
		Sounds = SeatbeltConfig.Sounds,
		ClientAudio = SeatbeltConfig.ClientAudio,
		SeatScopedActionsBySeatName = SeatbeltConfig.SeatScopedActionsBySeatName,
	}
end

--====================================================================
-- Factory Function
--====================================================================

function Seatbelt.create(context)
	return setmetatable({
		State = context.State,
		EnsureValue = context.EnsureValue,
		VehicleModel = context.VehicleModel,
		Seat = context.Seat,
		Config = SeatbeltConfig,
		Tags = SeatbeltTags,
		FrontPassengerSeat = nil,
	}, Seatbelt)
end

--====================================================================
-- Setup Functions
--====================================================================

function Seatbelt:setup()

	setupPluginSounds(self.VehicleModel)
	self.State.DriverSeatbelt = self.EnsureValue("BoolValue", "DriverSeatbelt", false)
	self.State.FrontPassengerSeatbelt = self.EnsureValue("BoolValue", "FrontPassengerSeatbelt", false)
	self.State.SeatbeltChime = self.EnsureValue("BoolValue", "SeatbeltChime", false)
	self.State.DriverSeatbelt.Value = false
	self.State.FrontPassengerSeatbelt.Value = false
	self.State.SeatbeltChime.Value = false
	self.FrontPassengerSeat = self.VehicleModel:FindFirstChild(self.Config.Seats.FrontPassengerSeatName, true)

	-- Find chime sound created by setupPluginSounds
	local body = self.VehicleModel:FindFirstChild("Body")
	if body then
		local soundsFolder = body:FindFirstChild("Sounds")
		if soundsFolder then
			self.ChimeSound = soundsFolder:FindFirstChild("SeatbeltChime")
		end
	end

	-- Find PBrake and Gear values for chime logic
	local chassisInterface = self.VehicleModel:FindFirstChild("A-Chassis Tune")
	if chassisInterface then
		local iface = chassisInterface:FindFirstChild("A-Chassis Interface")
		if iface then
			local values = iface:FindFirstChild("Values")
			if values then
				self.PBrake = values:FindFirstChild("PBrake")
				self.Gear = values:FindFirstChild("Gear")
			end
		end
	end
end

function Seatbelt:applyVisuals()
end

function Seatbelt:forceClosed()
	self.State.DriverSeatbelt.Value = false
	self.State.FrontPassengerSeatbelt.Value = false
	self.State.SeatbeltChime.Value = false
end

--====================================================================
-- Update Functions
--====================================================================

function Seatbelt:update(dt)
	local driverOccupied = self.Seat and self.Seat.Occupant ~= nil
	local frontPassengerOccupied = self.FrontPassengerSeat and (self.FrontPassengerSeat:IsA("Seat") or self.FrontPassengerSeat:IsA("VehicleSeat")) and self.FrontPassengerSeat.Occupant ~= nil

	if not driverOccupied then
		self.State.DriverSeatbelt.Value = false
	end
	if not frontPassengerOccupied then
		self.State.FrontPassengerSeatbelt.Value = false
	end

	-- Chime should only sound when vehicle is NOT in Park (PBrake off or gear not P)
	local isInPark = true
	if self.PBrake and self.PBrake:IsA("BoolValue") then
		isInPark = self.PBrake.Value
	end
	-- Also check gear value if available (gear 0 = Park in A-Chassis)
	if self.Gear and self.Gear:IsA("IntValue") then
		isInPark = isInPark or (self.Gear.Value == 0)
	end

	local shouldChime = false
	if not isInPark then
		shouldChime =
			(driverOccupied and self.State.DriverSeatbelt.Value ~= true)
			or (frontPassengerOccupied and self.State.FrontPassengerSeatbelt.Value ~= true)
	end

	self.State.SeatbeltChime.Value = shouldChime

	-- Play/stop the actual chime sound
	if self.ChimeSound and self.ChimeSound:IsA("Sound") then
		if shouldChime and not self.ChimeSound.IsPlaying then
			self.ChimeSound:Play()
		elseif not shouldChime and self.ChimeSound.IsPlaying then
			self.ChimeSound:Stop()
		end
	end
end

--====================================================================
-- Action Handling
--====================================================================

function Seatbelt:handleAction(action, payload, player)
	if action ~= self.Config.Actions.ToggleSeatbelt then
		return false
	end

	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seatPart = humanoid and humanoid.SeatPart
	if seatPart == self.Seat then
		self.State.DriverSeatbelt.Value = not self.State.DriverSeatbelt.Value
		return true
	end
	if seatPart and self.FrontPassengerSeat and seatPart == self.FrontPassengerSeat then
		self.State.FrontPassengerSeatbelt.Value = not self.State.FrontPassengerSeatbelt.Value
		return true
	end
	return false
end

return Seatbelt
