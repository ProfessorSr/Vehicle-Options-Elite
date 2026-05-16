00:07:21.424  Stack Begin  -  Studio
00:07:21.424  Script 'Players.KyaidehnRust.PlayerGui.A-Chassis Interface.Fuel', Line 24  -  Studio - Fuel:24
00:07:21.424  Stack End  -  Studio-- Fuel/Server.luau
-- Server-side DataStore persistence for the Fuel plugin.
-- Saves and restores FuelGallons per player across sessions.
--
-- Architecture:
--   On player join  → load saved gallons from DataStore → set "SavedFuelGallons" attribute on car
--   On player leave → read "FuelGallons" attribute from car → save to DataStore
--   Periodic save   → every Config.SaveIntervalSeconds, flush current value to DataStore
--
-- The LocalScript reads "SavedFuelGallons" attribute on the car during setup() to resume
-- from the last saved level instead of starting full.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

if RunService:IsClient() then
	return
end

-- ── Config ──────────────────────────────────────────────────────────────────

local DATASTORE_NAME    = "VOE_FuelGallons_v1"
local SAVE_INTERVAL_SEC = 60      -- how often to auto-save while the player is in the game
local MAX_GALLONS       = 18      -- fallback cap; overridden at runtime from the car attribute

-- ── Helpers ──────────────────────────────────────────────────────────────────

local fuelStore: DataStore = DataStoreService:GetDataStore(DATASTORE_NAME)

local function datastoreKey(player: Player): string
	return "player_" .. tostring(player.UserId)
end

-- Walk from startInst toward the root looking for a child named `name`.
local function resolveAncestorChild(startInst: Instance, name: string): Instance?
	local cursor: Instance? = startInst
	while cursor do
		local child = cursor:FindFirstChild(name)
		if child then
			return child
		end
		cursor = cursor.Parent
	end
	return nil
end

-- Find the car Model for a given player by walking their V O E   P L U G I N Ss subtree.
local function resolveCarForPlayer(player: Player): Model?
	local gui = script.Parent
	if not gui then
		return nil
	end
	local iface = script.Parent
	if not iface then
		return nil
	end
	local pluginRoot = iface:FindFirstChild("V O E   P L U G I N Ss")
	if not pluginRoot then
		return nil
	end
	local carValue = resolveAncestorChild(pluginRoot, "Car")
	if not carValue or not carValue:IsA("ObjectValue") then
		return nil
	end
	local car = carValue.Value
	if not car or not car:IsA("Model") then
		return nil
	end
	return car
end

-- ── Load ─────────────────────────────────────────────────────────────────────

local function loadFuelForPlayer(player: Player)
	local key = datastoreKey(player)
	local ok, result = pcall(function()
		return fuelStore:GetAsync(key)
	end)

	if not ok then
		warn("[Fuel/Server] DataStore GetAsync failed for", player.Name, ":", tostring(result))
		return
	end

	local savedGallons = tonumber(result)
	if savedGallons == nil then
		-- No saved data — let LocalScript start at full (default behaviour).
		return
	end

	-- Wait briefly for the vehicle to finish loading into PlayerGui.
	local car: Model? = nil
	for _ = 1, 20 do
		car = resolveCarForPlayer(player)
		if car then
			break
		end
		task.wait(1)
	end

	if not car then
		warn("[Fuel/Server] Could not resolve car for", player.Name, "— saved fuel not applied")
		return
	end

	local maxGallons = car:GetAttribute("FuelCapacityGallons") or MAX_GALLONS
	local clamped = math.clamp(savedGallons, 0, maxGallons)
	car:SetAttribute("SavedFuelGallons", clamped)
end

-- ── Save ─────────────────────────────────────────────────────────────────────

local function saveFuelForPlayer(player: Player)
	local car = resolveCarForPlayer(player)
	if not car then
		return
	end

	local gallons = car:GetAttribute("FuelGallons")
	if type(gallons) ~= "number" then
		return
	end

	local key = datastoreKey(player)
	local ok, err = pcall(function()
		fuelStore:SetAsync(key, gallons)
	end)

	if not ok then
		warn("[Fuel/Server] DataStore SetAsync failed for", player.Name, ":", tostring(err))
	end
end

-- ── Player lifecycle ─────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadFuelForPlayer, player)
end)

Players.PlayerRemoving:Connect(function(player)
	saveFuelForPlayer(player)
end)

-- Catch server shutdown: save everyone currently in the game.
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveFuelForPlayer(player)
	end
end)

-- ── Periodic auto-save ────────────────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(SAVE_INTERVAL_SEC)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(saveFuelForPlayer, player)
		end
	end
end)
