-- Server-side DataStore persistence for the Fuel plugin.
-- Saves and restores FuelGallons per player per vehicle across sessions.
--
-- Architecture:
--   Client calls FuelLoadRemote:InvokeServer(vehicleId) on setup → server returns saved gallons from DataStore
--   Client fires FuelSyncRemote:FireServer(vehicleId, gallons) periodically → server stores value in memory
--   On player leave / periodic interval / server shutdown → server flushes to DataStore
--
-- DataStore key format: player_<UserId>_vehicle_<VehicleId>

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Config ──────────────────────────────────────────────────────────────────

local DATASTORE_NAME = "VOE_FuelGallons_v1"
local SAVE_INTERVAL_SEC = 60
local MAX_GALLONS_CAP = 1000 -- reasonable upper bound to prevent abuse

-- ── DataStore ────────────────────────────────────────────────────────────────

local fuelStore
local dataStoreEnabled = false

local dsOk, dsErr = pcall(function()
	fuelStore = DataStoreService:GetDataStore(DATASTORE_NAME)
	dataStoreEnabled = true
end)

if not dsOk then
	warn("[FuelPersistence] DataStore not available - fuel will not persist across sessions:", tostring(dsErr))
end

-- ── State ────────────────────────────────────────────────────────────────────
-- playerFuel[userId][vehicleId] = current gallons

local playerFuel = {}

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function datastoreKey(userId: number, vehicleId: string): string
	return "player_" .. tostring(userId) .. "_vehicle_" .. vehicleId
end

-- ── Load ─────────────────────────────────────────────────────────────────────

local function loadFuelForPlayer(player: Player, vehicleId: string): number?
	if not dataStoreEnabled then return nil end

	local key = datastoreKey(player.UserId, vehicleId)
	local ok, result = pcall(function()
		return fuelStore:GetAsync(key)
	end)

	if not ok then
		warn("[FuelPersistence] DataStore GetAsync failed for", player.Name, vehicleId, ":", tostring(result))
		return nil
	end

	local savedGallons = tonumber(result)
	if savedGallons == nil then
		return nil -- No saved data — client will use default (full tank)
	end

	-- Cache in memory
	if not playerFuel[player.UserId] then
		playerFuel[player.UserId] = {}
	end
	playerFuel[player.UserId][vehicleId] = savedGallons

	return savedGallons
end

-- ── Save ─────────────────────────────────────────────────────────────────────

local function saveFuelForPlayer(player: Player, vehicleId: string)
	if not dataStoreEnabled then return end

	local userId = player.UserId
	local vehicleData = playerFuel[userId]
	if not vehicleData then return end

	local gallons = vehicleData[vehicleId]
	if gallons == nil then return end

	local key = datastoreKey(userId, vehicleId)
	local ok, err = pcall(function()
		fuelStore:SetAsync(key, gallons)
	end)

	if not ok then
		warn("[FuelPersistence] DataStore SetAsync failed for", player.Name, vehicleId, ":", tostring(err))
	end
end

local function saveAllFuelForPlayer(player: Player)
	if not dataStoreEnabled then return end

	local userId = player.UserId
	local vehicleData = playerFuel[userId]
	if not vehicleData then return end

	for vehicleId, gallons in pairs(vehicleData) do
		local key = datastoreKey(userId, vehicleId)
		local ok, err = pcall(function()
			fuelStore:SetAsync(key, gallons)
		end)
		if not ok then
			warn("[FuelPersistence] DataStore SetAsync failed for", player.Name, vehicleId, ":", tostring(err))
		end
	end
end

-- ── RemoteEvent / RemoteFunction Setup ────────────────────────────────────────

local fuelLoadRemote = ReplicatedStorage:FindFirstChild("FuelLoadRemote")
local fuelSyncRemote = ReplicatedStorage:FindFirstChild("FuelSyncRemote")

if not fuelLoadRemote then
	warn("[FuelPersistence] FuelLoadRemote not found in ReplicatedStorage")
end
if not fuelSyncRemote then
	warn("[FuelPersistence] FuelSyncRemote not found in ReplicatedStorage")
end

-- Client requests their saved fuel level for a specific vehicle (called during Fuel plugin setup)
if fuelLoadRemote then
	fuelLoadRemote.OnServerInvoke = function(player: Player, vehicleId: string)
		if type(vehicleId) ~= "string" or vehicleId == "" then
			vehicleId = "default"
		end
		local savedGallons = loadFuelForPlayer(player, vehicleId)
		return savedGallons -- nil if no saved data; client will fall back to default
	end
end

-- Client sends periodic fuel updates for a specific vehicle
if fuelSyncRemote then
	fuelSyncRemote.OnServerEvent:Connect(function(player: Player, vehicleId: string, gallons: number)
		if type(vehicleId) ~= "string" or vehicleId == "" then
			vehicleId = "default"
		end
		if type(gallons) == "number" then
			if not playerFuel[player.UserId] then
				playerFuel[player.UserId] = {}
			end
			playerFuel[player.UserId][vehicleId] = math.clamp(gallons, 0, MAX_GALLONS_CAP)
		end
	end)
end

-- ── Player lifecycle ─────────────────────────────────────────────────────────

Players.PlayerRemoving:Connect(function(player: Player)
	saveAllFuelForPlayer(player)
	playerFuel[player.UserId] = nil
end)

-- Catch server shutdown: save everyone currently in the game.
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveAllFuelForPlayer(player)
	end
end)

-- ── Periodic auto-save ────────────────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(SAVE_INTERVAL_SEC)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(saveAllFuelForPlayer, player)
		end
	end
end)

print("[FuelPersistence] Fuel DataStore persistence initialized (DataStore " .. (dataStoreEnabled and "enabled" or "disabled") .. ")")
