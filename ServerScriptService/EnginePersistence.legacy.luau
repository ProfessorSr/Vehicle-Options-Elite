-- Server-side DataStore persistence for the Engine plugin.
-- Saves and restores engine state per player per vehicle across sessions.
--
-- Architecture:
--   Client calls EngineLoadRemote:InvokeServer(vehicleId) on setup → server returns saved state from DataStore
--   Client fires EngineSyncRemote:FireServer(vehicleId, stateTable) periodically → server stores in memory
--   On player leave / periodic interval / server shutdown → server flushes to DataStore
--
-- DataStore key format: player_<UserId>_vehicle_<VehicleId>

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Config ──────────────────────────────────────────────────────────────────

local DATASTORE_NAME = "VOE_EngineState_v1"
local SAVE_INTERVAL_SEC = 60

-- ── DataStore ────────────────────────────────────────────────────────────────

local engineStore
local dataStoreEnabled = false

local dsOk, dsErr = pcall(function()
	engineStore = DataStoreService:GetDataStore(DATASTORE_NAME)
	dataStoreEnabled = true
end)

if not dsOk then
	warn("[EnginePersistence] DataStore not available - engine state will not persist across sessions:", tostring(dsErr))
end

-- ── State ────────────────────────────────────────────────────────────────────
-- playerEngine[userId][vehicleId] = { EngineWear = ..., EngineTemp = ..., ... }

local playerEngine = {}

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function datastoreKey(userId: number, vehicleId: string): string
	return "player_" .. tostring(userId) .. "_vehicle_" .. vehicleId
end

-- ── Load ─────────────────────────────────────────────────────────────────────

local function loadEngineForPlayer(player: Player, vehicleId: string): table?
	if not dataStoreEnabled then return nil end

	local key = datastoreKey(player.UserId, vehicleId)
	local ok, result = pcall(function()
		return engineStore:GetAsync(key)
	end)

	if not ok then
		warn("[EnginePersistence] DataStore GetAsync failed for", player.Name, vehicleId, ":", tostring(result))
		return nil
	end

	if type(result) ~= "table" then
		return nil -- No saved data — client will use defaults
	end

	-- Cache in memory
	if not playerEngine[player.UserId] then
		playerEngine[player.UserId] = {}
	end
	playerEngine[player.UserId][vehicleId] = result

	return result
end

-- ── Save ─────────────────────────────────────────────────────────────────────

local function saveEngineForPlayer(player: Player, vehicleId: string)
	if not dataStoreEnabled then return end

	local userId = player.UserId
	local vehicleData = playerEngine[userId]
	if not vehicleData then return end

	local state = vehicleData[vehicleId]
	if state == nil then return end

	local key = datastoreKey(userId, vehicleId)
	local ok, err = pcall(function()
		engineStore:SetAsync(key, state)
	end)

	if not ok then
		warn("[EnginePersistence] DataStore SetAsync failed for", player.Name, vehicleId, ":", tostring(err))
	end
end

local function saveAllEngineForPlayer(player: Player)
	if not dataStoreEnabled then return end

	local userId = player.UserId
	local vehicleData = playerEngine[userId]
	if not vehicleData then return end

	for vehicleId, state in pairs(vehicleData) do
		local key = datastoreKey(userId, vehicleId)
		local ok, err = pcall(function()
			engineStore:SetAsync(key, state)
		end)
		if not ok then
			warn("[EnginePersistence] DataStore SetAsync failed for", player.Name, vehicleId, ":", tostring(err))
		end
	end
end

-- ── RemoteEvent / RemoteFunction Setup ────────────────────────────────────────

local engineLoadRemote = ReplicatedStorage:FindFirstChild("EngineLoadRemote")
local engineSyncRemote = ReplicatedStorage:FindFirstChild("EngineSyncRemote")

if not engineLoadRemote then
	warn("[EnginePersistence] EngineLoadRemote not found in ReplicatedStorage")
end
if not engineSyncRemote then
	warn("[EnginePersistence] EngineSyncRemote not found in ReplicatedStorage")
end

-- Client requests saved engine state for a specific vehicle (called during Engine plugin setup)
if engineLoadRemote then
	engineLoadRemote.OnServerInvoke = function(player: Player, vehicleId: string)
		if type(vehicleId) ~= "string" or vehicleId == "" then
			vehicleId = "default"
		end
		return loadEngineForPlayer(player, vehicleId)
	end
end

-- Client sends periodic engine state updates for a specific vehicle
if engineSyncRemote then
	engineSyncRemote.OnServerEvent:Connect(function(player: Player, vehicleId: string, stateTable: table)
		if type(vehicleId) ~= "string" or vehicleId == "" then
			vehicleId = "default"
		end
		if type(stateTable) == "table" then
			if not playerEngine[player.UserId] then
				playerEngine[player.UserId] = {}
			end
			-- Validate and clamp values to prevent abuse
			local sanitized = {}
			sanitized.EngineWear = math.clamp(tonumber(stateTable.EngineWear) or 100, 0, 100)
			sanitized.EngineTemp = math.clamp(tonumber(stateTable.EngineTemp) or 80, 0, 500)
			sanitized.CoolantLevel = math.clamp(tonumber(stateTable.CoolantLevel) or 100, 0, 100)
			sanitized.CoolantTemp = math.clamp(tonumber(stateTable.CoolantTemp) or 180, 0, 500)
			sanitized.OilLevel = math.clamp(tonumber(stateTable.OilLevel) or 100, 0, 100)
			sanitized.OilPressure = math.clamp(tonumber(stateTable.OilPressure) or 24, 0, 200)
			sanitized.BatteryPercent = math.clamp(tonumber(stateTable.BatteryPercent) or 100, 0, 100)
			sanitized.BatteryCondition = math.clamp(tonumber(stateTable.BatteryCondition) or 100, 0, 100)
			sanitized.MaintenanceMilesRemaining = math.clamp(tonumber(stateTable.MaintenanceMilesRemaining) or 5000, 0, 100000)
			sanitized.CheckEngine = stateTable.CheckEngine == true
			playerEngine[player.UserId][vehicleId] = sanitized
		end
	end)
end

-- ── Player lifecycle ─────────────────────────────────────────────────────────

Players.PlayerRemoving:Connect(function(player: Player)
	saveAllEngineForPlayer(player)
	playerEngine[player.UserId] = nil
end)

-- Catch server shutdown: save everyone currently in the game.
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveAllEngineForPlayer(player)
	end
end)

-- ── Periodic auto-save ────────────────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(SAVE_INTERVAL_SEC)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(saveAllEngineForPlayer, player)
		end
	end
end)

print("[EnginePersistence] Engine DataStore persistence initialized (DataStore " .. (dataStoreEnabled and "enabled" or "disabled") .. ")")