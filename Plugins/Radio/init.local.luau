-- V O E   P L U G I N S • Radio
-- DATE (UTC):
--
-- DESCRIPTION:
-- Handles in-vehicle radio with station/track switching.
-- Auto-plays when seated, pauses when not.
--
-- NOTES:
-- - Client-side keybinds only (LocalScript)
-- - Single Sound object on DriveSeat
-- - Station/track data from Sounds module

--====================================================================
-- Module Requires
--====================================================================

local Config = require(script:WaitForChild("Config"))
local Tags = require(script:WaitForChild("Tags"))
local PluginSounds = require(script:WaitForChild("Sounds"))

if Config and Config.Enabled == false then
	warn("[Radio] Plugin disabled via config")
	return
end

--====================================================================
-- Services
--====================================================================

local RunService = game:GetService("RunService")
local isClient = RunService:IsClient()

--====================================================================
-- Vehicle Resolution
--====================================================================

local plugin = script.Parent

local function findVehicle()
	local carValue = plugin:FindFirstChild("Car")
	if carValue and carValue:IsA("ObjectValue") and carValue.Value then
		return carValue.Value
	end
	return plugin:FindFirstAncestorOfClass("Model")
end

local vehicle = findVehicle()
if not vehicle then
	warn("[Radio] Could not find vehicle model")
	return
end

-- Find DriveSeat
local driveSeat = vehicle:FindFirstChild("DriveSeat", true)
if not driveSeat then
	warn("[Radio] No DriveSeat found")
	return
end

--====================================================================
-- Sound Object
--====================================================================

-- Reuse existing RadioSound if already created (prevents duplicates)
local sound = driveSeat:FindFirstChild("RadioSound")
if not sound or not sound:IsA("Sound") then
	if sound then sound.Parent = nil end
	sound = Instance.new("Sound")
	sound.Name = "RadioSound"
	sound.Parent = driveSeat
end
sound.Volume = Config.DefaultVolume or 0.5
sound.Looped = false

--====================================================================
-- State
--====================================================================

local currentStationIndex = 1
local currentTrackIndex = 1
local isPlaying = false

--====================================================================
-- Helpers
--====================================================================

local function getStation()
	return PluginSounds.Stations[currentStationIndex]
end

local function getTrack()
	local station = getStation()
	if not station then return nil end
	return station.Tracks[currentTrackIndex]
end

local function playTrack()
	local track = getTrack()
	if not track then return end
	sound.SoundId = track.Id
	sound:Play()
	isPlaying = true
end

local function nextTrack()
	local station = getStation()
	if not station then return end
	if Config.Shuffle then
		currentTrackIndex = math.random(1, #station.Tracks)
	else
		currentTrackIndex += 1
		if currentTrackIndex > #station.Tracks then
			currentTrackIndex = 1
		end
	end
	playTrack()
end

local function nextStation()
	currentStationIndex += 1
	if currentStationIndex > #PluginSounds.Stations then
		currentStationIndex = 1
	end
	currentTrackIndex = 1
	playTrack()
end

local function togglePlay()
	if isPlaying then
		sound:Pause()
		isPlaying = false
	else
		if sound.SoundId ~= "" then
			sound:Resume()
		else
			playTrack()
		end
		isPlaying = true
	end
end

--====================================================================
-- Auto Advance
--====================================================================

sound.Ended:Connect(function()
	nextTrack()
end)

--====================================================================
-- Client-Side Keybinds
--====================================================================

if isClient then
	local UserInputService = game:GetService("UserInputService")
	local Players = game:GetService("Players")

	local function isSeatedInVehicle()
		local player = Players.LocalPlayer
		if not player then return false end
		local character = player.Character
		if not character then return false end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or not humanoid.SeatPart then return false end
		return humanoid.SeatPart == driveSeat
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if not isSeatedInVehicle() then return end

		local keybinds = Config.Keybinds or {}
		if input.KeyCode == (keybinds.NextStation or Enum.KeyCode.K) then
			nextStation()
		elseif input.KeyCode == (keybinds.NextTrack or Enum.KeyCode.N) then
			nextTrack()
		elseif input.KeyCode == (keybinds.TogglePlay or Enum.KeyCode.B) then
			togglePlay()
		end
	end)
end

--====================================================================
-- Auto-Play Loop
--====================================================================

task.spawn(function()
	while true do
		local occupied = driveSeat.Occupant ~= nil
		if occupied then
			if Config.AutoPlay and not isPlaying then
				playTrack()
			end
		else
			if isPlaying then
				sound:Pause()
				isPlaying = false
			end
		end
		task.wait(1)
	end
end)
