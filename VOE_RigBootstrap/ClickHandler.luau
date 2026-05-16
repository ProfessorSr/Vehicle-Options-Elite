 
-- V O E   P L U G I N S • ClickHandler
-- DATE (UTC): 2026-03-21 13:27 UTC
--
-- DESCRIPTION:
-- Handles click detection for VOE plugins. Parts tagged with VOE_Click_*
-- get a ClickDetector that triggers the associated action.
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)

-- - Uses VOE_State folder created by VOE_RigBootstrap for persistent state
-- - Supports click detector, keybind, or both interaction modes
-- - Click-through support via VOE_ClickThrough tag on obstructing parts

local ClickHandler = {}

--====================================================================
-- Configuration
--====================================================================

ClickHandler.Config = {
	-- Master enable
	Enabled = true,

	-- Interaction mode: "Click", "ProximityPrompt", or "Both"
	InteractionMode = "Click",

	-- ClickDetector settings
	ClickSettings = {
		MaxActivationDistance = 15, -- studs (increased for better reach)
		CursorIcon = "", -- leave empty for default
	},

	-- ProximityPrompt settings
	   ProximitySettings = {
		   ActionText = "Interact",
		   ObjectText = "",
		   KeyboardKeyCode = Enum.KeyCode.E,
		   HoldDuration = 0,
		   MaxActivationDistance = 2,
	   },

	-- Click-through settings
	-- Parts tagged with VOE_ClickThrough will be made non-collidable for clicking
	ClickThroughEnabled = true,

	-- Debug settings
	Debug = {
		Enabled = true,
		LogClicks = true,
	},
}

--====================================================================
-- Services
--====================================================================

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

--====================================================================
-- State Management
--====================================================================

-- VOE_State folder reference - passed from VOE_RigBootstrap
local VOE_StateFolder = nil
local Vehicle = nil
local ClickDetectors = {} -- Maps part -> ClickDetector
local ClickConnections = {} -- Maps part -> connection
local ClickThroughParts = {} -- Parts that should allow click-through

--====================================================================
-- Helper Functions
--====================================================================

local function debugLog(category, message)
	if not ClickHandler.Config.Debug.Enabled then return end
	print(string.format("[ClickHandler][%s] %s", category, message))
end

-- Get the VOE_State folder (set by Initialize)
function ClickHandler.GetStateFolder()
	return VOE_StateFolder
end

-- Get or create a value in the VOE_State folder
-- This is the primary API for plugins to create state values
function ClickHandler.GetOrCreateValue(valueName, className, defaultValue, owner)
	if not VOE_StateFolder then
		warn("[ClickHandler] VOE_State folder not initialized")
		return nil
	end

	local existing = VOE_StateFolder:FindFirstChild(valueName)
	if existing then return existing end

	local value = Instance.new(className)
	value.Name = valueName
	value.Parent = VOE_StateFolder
	value:SetAttribute("VOE_Owner", owner or "Unknown")
	value:SetAttribute("VOE_Type", "State")

	if className == "BoolValue" then
		value.Value = defaultValue or false
	elseif className == "NumberValue" then
		value.Value = defaultValue or 0
	elseif className == "StringValue" then
		value.Value = defaultValue or ""
	elseif className == "IntValue" then
		value.Value = defaultValue or 0
	end

	debugLog("State", "Created " .. valueName .. " (" .. className .. ") for " .. (owner or "Unknown"))
	return value
end

-- Get a state value by name
function ClickHandler.GetStateValue(valueName)
	if not VOE_StateFolder then return nil end
	return VOE_StateFolder:FindFirstChild(valueName)
end

-- Set a state value by name
function ClickHandler.SetStateValue(valueName, value)
	local stateValue = ClickHandler.GetStateValue(valueName)
	if stateValue then
		stateValue.Value = value
		return true
	end
	return false
end

-- Toggle a BoolValue state
function ClickHandler.ToggleStateValue(valueName)
	local stateValue = ClickHandler.GetStateValue(valueName)
	if stateValue and stateValue:IsA("BoolValue") then
		stateValue.Value = not stateValue.Value
		return stateValue.Value
	end
	return nil
end

--====================================================================
-- Click-Through Handling
--====================================================================

-- Setup click-through for obstructing parts
-- Parts tagged with VOE_ClickThrough will have CanCollide set to false
-- This allows clicks to pass through them to clickable parts behind
local function setupClickThroughPart(part)
	if not ClickHandler.Config.ClickThroughEnabled then return end

	-- Store original CanCollide state
	if not ClickThroughParts[part] then
		ClickThroughParts[part] = part.CanCollide
		-- Make the part non-collidable for click-through
		-- Note: This affects physics, but allows clicks to pass through
		part.CanCollide = false
		debugLog("ClickThrough", "Set " .. part.Name .. " to non-collidable for click-through")
	end
end

-- Restore original CanCollide state
local function restoreClickThroughPart(part)
	if ClickThroughParts[part] ~= nil then
		part.CanCollide = ClickThroughParts[part]
		ClickThroughParts[part] = nil
		debugLog("ClickThrough", "Restored " .. part.Name .. " CanCollide state")
	end
end

-- Scan for click-through parts
local function scanForClickThroughParts(vehicle)
	local body = vehicle:FindFirstChild("Body")
	if not body then return end

	for _, descendant in ipairs(body:GetDescendants()) do
		if descendant:IsA("BasePart") then
			for _, tag in ipairs(CollectionService:GetTags(descendant)) do
				if tag == "VOE_ClickThrough" then
					setupClickThroughPart(descendant)
				end
			end
		end
	end
end

--====================================================================
-- Click Detection
--====================================================================

-- Extract the role name from a click tag (e.g., "VOE_Click_DoorFL" -> "DoorFL")
local function extractRoleFromClickTag(tagName)
	local role = string.match(tagName, "^VOE_Click_(.+)$")
	return role
end

-- Find the associated state value for a click tag
local function findAssociatedStateValue(clickTag)
	local role = extractRoleFromClickTag(clickTag)
	if not role then return nil end

	-- Look in VOE_State folder
	if VOE_StateFolder then
		local stateValue = VOE_StateFolder:FindFirstChild(role)
		if stateValue then return stateValue end
	end

	return nil
end


-- Create a ClickDetector for a part
local function createClickDetector(part, clickTag)
	local mode = ClickHandler.Config.InteractionMode
	if mode ~= "Click" and mode ~= "Both" then
		return nil
	end

	if ClickDetectors[part] then
		return ClickDetectors[part]
	end

	local size = part.Size
	local maxDimension = math.max(size.X, size.Y, size.Z)
	local baseDistance = maxDimension / 2 + 5
	local activationDistance = math.max(baseDistance, ClickHandler.Config.ClickSettings.MaxActivationDistance)

	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = activationDistance
	clickDetector.Parent = part

	ClickDetectors[part] = clickDetector

	debugLog("Setup", "Created ClickDetector on " .. part.Name .. " (tag: " .. clickTag .. ", distance: " .. activationDistance .. ")")

	return clickDetector
end

-- Create a ProximityPrompt for a part
local ProximityPrompts = {} -- Maps part -> ProximityPrompt
local function createProximityPrompt(part, clickTag)
	local mode = ClickHandler.Config.InteractionMode
	if mode ~= "ProximityPrompt" and mode ~= "Both" then
		return nil
	end

	if ProximityPrompts[part] then
		return ProximityPrompts[part]
	end

	local settings = ClickHandler.Config.ProximitySettings
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = settings.ActionText or "Interact"
	prompt.ObjectText = settings.ObjectText or part.Name
	prompt.KeyboardKeyCode = settings.KeyboardKeyCode or Enum.KeyCode.E
	prompt.HoldDuration = settings.HoldDuration or 0
	prompt.MaxActivationDistance = settings.MaxActivationDistance or 10
	prompt.Parent = part

	ProximityPrompts[part] = prompt

	debugLog("Setup", "Created ProximityPrompt on " .. part.Name .. " (tag: " .. clickTag .. ")")

	return prompt
end

-- Handle click on a part
local function handleClick(part, clickTag, player)
	local role = extractRoleFromClickTag(clickTag)
	if not role then return end

	debugLog("Click", "Player " .. player.Name .. " clicked " .. role .. " on " .. part.Name)

	

	-- Special handling for Hood: check if unlocked
	if role == "Hood" then
		local unlockedValue = VOE_StateFolder and VOE_StateFolder:FindFirstChild("HoodUnlocked")
		if unlockedValue then
			if not unlockedValue.Value then
				debugLog("Click", "Hood is locked - click ignored")
				return
			end
		end
	end

	-- Special handling for Doors: check child lock
	if string.sub(role, 1, 4) == "Door" then
		-- Check if this is a rear door with child lock
		local DoorsHandler = script.Parent:FindFirstChild("DoorsHandler")
		if DoorsHandler then
			local success, isChildLocked = pcall(function()
				local handler = require(DoorsHandler)
				return handler.IsChildLocked and handler.IsChildLocked(role)
			end)
			if success and isChildLocked then
				-- Check if player is seated in this vehicle (inside click)
				local character = player.Character
				if character then
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid.SeatPart then
						-- Player is seated - check if they're in this vehicle
						local seat = humanoid.SeatPart
						if seat:IsDescendantOf(Vehicle) then
							-- Check if door is currently closed (trying to open)
							local doorState = VOE_StateFolder and VOE_StateFolder:FindFirstChild(role)
							if doorState and doorState:IsA("BoolValue") and not doorState.Value then
								-- Door is closed - block opening from inside
								debugLog("Click", role .. " has child lock - cannot open from inside")
								return
							end
							-- Door is open - allow closing from inside (fall through)
						end
					end
				end
			end
		end
	end

	-- Special handling for WindowsAll click interaction
	if role == "WindowsAll" then
		local toggled = false
		for _, windowRole in ipairs({"WindowFL", "WindowFR", "WindowRL", "WindowRR"}) do
			local windowState = VOE_StateFolder and VOE_StateFolder:FindFirstChild(windowRole)
			if windowState and windowState:IsA("BoolValue") then
				windowState.Value = not windowState.Value
				toggled = true
			end
		end
		if toggled then
			debugLog("Click", "Toggled all windows via WindowsAll click tag")
		end
		return
	end

	-- Find the associated state value and toggle it
	local stateValue = findAssociatedStateValue(clickTag)
	if stateValue and stateValue:IsA("BoolValue") then
		stateValue.Value = not stateValue.Value
		debugLog("Click", "Toggled " .. role .. " to " .. tostring(stateValue.Value))
	else
		-- If no state value exists, create one and toggle it
		debugLog("Click", "No state value found for " .. role .. ", creating one")
		stateValue = ClickHandler.GetOrCreateValue(role, "BoolValue", false, "ClickHandler")
		if stateValue then
			stateValue.Value = not stateValue.Value
			debugLog("Click", "Created and toggled " .. role .. " to " .. tostring(stateValue.Value))
		end
	end
end


local function setupClickDetection(part, clickTag)
	local clickDetector = createClickDetector(part, clickTag)
	local proximityPrompt = createProximityPrompt(part, clickTag)

	if clickDetector then
		if ClickConnections[part] then
			ClickConnections[part]:Disconnect()
		end
		ClickConnections[part] = clickDetector.MouseClick:Connect(function(player)
			handleClick(part, clickTag, player)
		end)
	end

	if proximityPrompt then
		if ClickConnections[proximityPrompt] then
			ClickConnections[proximityPrompt]:Disconnect()
		end
		ClickConnections[proximityPrompt] = proximityPrompt.Triggered:Connect(function(player)
			handleClick(part, clickTag, player)
		end)
	end
end


local function removeClickDetection(part)
	if ClickConnections[part] then
		ClickConnections[part]:Disconnect()
		ClickConnections[part] = nil
	end
	for prompt, conn in pairs(ClickConnections) do
		if typeof(prompt) == "Instance" and prompt:IsA("ProximityPrompt") and prompt.Parent == part then
			conn:Disconnect()
			ClickConnections[prompt] = nil
		end
	end

	if ClickDetectors[part] then
		ClickDetectors[part]:Destroy()
		ClickDetectors[part] = nil
	end
	if ProximityPrompts and ProximityPrompts[part] then
		ProximityPrompts[part]:Destroy()
		ProximityPrompts[part] = nil
	end
end

--====================================================================
-- Tag Scanning
--====================================================================

-- Find all click tags on a part
local function getClickTags(part)
	local clickTags = {}
	for _, tag in ipairs(CollectionService:GetTags(part)) do
		if string.match(tag, "^VOE_Click_") then
			table.insert(clickTags, tag)
		end
		-- Also support the xx_xx_Click pattern
		if string.match(tag, "_.+_Click$") then
			table.insert(clickTags, tag)
		end
	end
	return clickTags
end

--====================================================================
-- RemoteEvent Creation
--====================================================================

-- Create RemoteEvents for client-server communication
-- These are used for vehicle entry/exit requests
local function createRemoteEvents()
	if not Vehicle then return end
	
	local remoteEvents = {
		"EnterVehicleRequest",
		"ExitVehicleRequest",
		"EnterSeatRequest",
		"ExitSeatRequest",
	}
	
	for _, eventName in ipairs(remoteEvents) do
		local existing = Vehicle:FindFirstChild(eventName)
		if not existing then
			local remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Name = eventName
			remoteEvent.Parent = Vehicle
			debugLog("Setup", "Created RemoteEvent: " .. eventName)
		end
	end
end

--====================================================================
-- Public API
--====================================================================

-- Initialize the click handler with a vehicle reference and VOE_State folder
function ClickHandler.Initialize(vehicle, stateFolder)
	Vehicle = vehicle
	VOE_StateFolder = stateFolder

	if not VOE_StateFolder then
		warn("[ClickHandler] VOE_State folder not provided, attempting to find it")
		VOE_StateFolder = vehicle:FindFirstChild("VOE_State")
	end

	-- Create RemoteEvents for vehicle entry/exit
	createRemoteEvents()

	-- Scan for click-through parts first
	scanForClickThroughParts(vehicle)

	-- Scan for all parts with click tags in the entire vehicle
	debugLog("Init", "Scanning " .. #vehicle:GetDescendants() .. " descendants for click tags")
	for _, descendant in ipairs(vehicle:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local clickTags = getClickTags(descendant)
			if #clickTags > 0 then
				debugLog("Init", "Found " .. #clickTags .. " click tags on " .. descendant.Name)
			end
			-- Check for click-through tag
			for _, tag in ipairs(CollectionService:GetTags(descendant)) do
				if tag == "VOE_ClickThrough" then
					setupClickThroughPart(descendant)
				end
			end

			-- Check for click tags
			for _, clickTag in ipairs(clickTags) do
				setupClickDetection(descendant, clickTag)
			end
		end
	end

	-- Listen for new parts being added anywhere in the vehicle
	vehicle.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			task.wait(0.1) -- Small delay to ensure tags are applied

			-- Check for click-through tag
			for _, tag in ipairs(CollectionService:GetTags(descendant)) do
				if tag == "VOE_ClickThrough" then
					setupClickThroughPart(descendant)
				end
			end

			-- Check for click tags
			local clickTags = getClickTags(descendant)
			for _, clickTag in ipairs(clickTags) do
				setupClickDetection(descendant, clickTag)
			end
		end
	end)

	-- Listen for parts being removed
	vehicle.DescendantRemoving:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			removeClickDetection(descendant)
			restoreClickThroughPart(descendant)
		end
	end)

	debugLog("Init", "ClickHandler initialized for " .. vehicle.Name)
end

-- Get the current interaction mode
function ClickHandler.GetInteractionMode()
	return ClickHandler.Config.InteractionMode
end

-- Set the interaction mode
function ClickHandler.SetInteractionMode(mode)
	if mode == "Click" or mode == "ProximityPrompt" or mode == "Both" then
		ClickHandler.Config.InteractionMode = mode
		debugLog("Config", "Interaction mode set to " .. mode)
	end
end

-- Check if click detection is enabled
function ClickHandler.IsClickEnabled()
	local mode = ClickHandler.Config.InteractionMode
	return mode == "Click" or mode == "Both"
end

--====================================================================
-- Return
--====================================================================

return ClickHandler