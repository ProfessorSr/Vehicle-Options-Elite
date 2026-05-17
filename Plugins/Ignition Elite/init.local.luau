 
-- V O E   P L U G I N S • Ignition
-- DATE (UTC):
--
-- DESCRIPTION:
-- Plugin entry point.
--
-- NOTES:
-- - Tag-driven system (no part hierarchy assumptions)

-- - Clean, modular, no deprecated code

--====================================================================
-- Module Requires
--====================================================================

local Config = require(script:WaitForChild("Config"))

--====================================================================
-- Services
--====================================================================

local UserInputService = game:GetService("UserInputService")

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
		if voeState then
			return vehicle, voeState
		end
		-- Fallback to Values folder (legacy)
		return vehicle, valuesFolder
	end
	return nil, valuesFolder
end

--====================================================================
-- Configuration
--====================================================================

if Config and Config.Enabled == false then
	warn("[Ignition] Plugin disabled via config")
	return
end

local keybinds = Config.Keybinds or {}
local IGNITION_KEYBOARD = keybinds.Ignition or Enum.KeyCode.F
local IGNITION_CONTROLLER = keybinds.IgnitionController or Enum.KeyCode.ButtonB
local BRAKE_KEYBOARD = keybinds.Brake or Enum.KeyCode.S
local BRAKE_CONTROLLER = keybinds.BrakeController or Enum.KeyCode.ButtonL2

local gamepadPresent = UserInputService.GamepadEnabled

local pluginContainer = script.Parent:FindFirstChild("IsOn") and script.Parent or script.Parent.Parent
local isOnValue = pluginContainer:WaitForChild("IsOn")
local startingValue = isOnValue:WaitForChild("Starting")
local runtimeCar, runtimeValues = findRuntimeCarAndValues()
local valuesFolder = runtimeValues
local brakeValue = valuesFolder and valuesFolder:FindFirstChild("Brake")
local interfaceGui = script:FindFirstAncestorOfClass("ScreenGui")

--====================================================================
-- Helper Functions
--====================================================================


local function debugLog(category, message)
end

local function getOrCreatePromptLabel()
	if script.Parent:IsA("TextLabel") then
		return script.Parent
	end

	if not interfaceGui then
		return nil
	end

	local label = interfaceGui:FindFirstChild("VOE_IgnitionPrompt")
	if label and label:IsA("TextLabel") then
		return label
	end

	label = Instance.new("TextLabel")
	label.Name = "VOE_IgnitionPrompt"
	label.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	label.BackgroundTransparency = 0.35
	label.Size = UDim2.fromOffset(520, 28)
	label.Position = UDim2.fromScale(0.5, 0.08)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.TextScaled = false
	label.TextSize = 18
	label.RichText = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.8
	label.Text = ""
	label.ZIndex = 25
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	label.Parent = interfaceGui

	return label
end

local promptLabel = getOrCreatePromptLabel()

local function resolveTune(vehicle)
	if not vehicle then
		return nil
	end
	local candidates = {"Tune", "VehicleTune", "Vehicle Tune"}
	local tuneModule = nil
	for _, name in ipairs(candidates) do
		tuneModule = vehicle:FindFirstChild(name) or vehicle:FindFirstChild(name, true)
		if tuneModule and tuneModule:IsA("ModuleScript") then
			break
		end
		tuneModule = nil
	end
	if tuneModule and tuneModule:IsA("ModuleScript") then
		local ok, tune = pcall(require, tuneModule)
		if ok and type(tune) == "table" then
			return tune
		end
	end
	return nil
end

local tune = runtimeCar and resolveTune(runtimeCar) or nil
local autoStart = tune and tune.AutoStart == true or false

local function resolveHoldTimeSeconds()
	if not tune then return 0.7 end
	for _, key in ipairs({"StartTime", "StartDuration", "IgnitionTime", "StartupTime"}) do
		local v = tune[key]
		if type(v) == "number" and v > 0 then
			return v
		end
	end
	return 0.7
end

local holdToStartSeconds = resolveHoldTimeSeconds()

local accValue = isOnValue:FindFirstChild("ACC")
if not accValue then
	accValue = Instance.new("BoolValue")
	accValue.Name = "ACC"
	accValue.Value = false
	accValue.Parent = isOnValue
	accValue:SetAttribute("VOE_Owner", "Ignition")
	accValue:SetAttribute("VOE_Type", "State")
end

local pressActive = false
local pressBeganAt = 0
local startedThisPress = false
local allowStartThisPress = false
local enteredAccThisPress = false

local function isBrakeHeld()
	local brakeInputHeld = UserInputService:IsKeyDown(BRAKE_KEYBOARD) or UserInputService:IsKeyDown(BRAKE_CONTROLLER)
	if brakeInputHeld then
		return true
	end

	if brakeValue then
		if brakeValue:IsA("BoolValue") then
			return brakeValue.Value
		end
		return (brakeValue.Value or 0) > 0.05
	end

	return false
end

local function onInput(input:InputObject, gameProcessedEvent:boolean)
	if gameProcessedEvent then return end
	if not (input.KeyCode == IGNITION_KEYBOARD or input.KeyCode == IGNITION_CONTROLLER) then return end

	if input.UserInputState == Enum.UserInputState.Begin then
		pressActive = true
		pressBeganAt = tick()
		startedThisPress = false
		allowStartThisPress = false
		enteredAccThisPress = false

		if isOnValue.Value and not startingValue.Value then
			isOnValue.Value = false
			accValue.Value = false
			pressActive = false
			return
		end

		if autoStart then
			return
		end

		if not accValue.Value then
			accValue.Value = true
			if not isBrakeHeld() then
				enteredAccThisPress = true
				return
			end
			allowStartThisPress = true
		else
			allowStartThisPress = true
		end

		task.delay(holdToStartSeconds, function()
			if not pressActive then return end
			if not allowStartThisPress then return end
			if isOnValue.Value then return end
			if not accValue.Value then return end
			startingValue.Value = true
			startedThisPress = true
		end)
	elseif input.UserInputState == Enum.UserInputState.End then
		if autoStart then
			return
		end

		pressActive = false
		startingValue.Value = false

		if enteredAccThisPress then
			return
		end

		if not allowStartThisPress then
			return
		end

		local wasTap = (tick() - pressBeganAt) < holdToStartSeconds and not startedThisPress
		if wasTap and not isOnValue.Value and accValue.Value then
			accValue.Value = false
		end
	end
end

local function update()
	if not promptLabel then
		promptLabel = getOrCreatePromptLabel()
		if not promptLabel then
			return
		end
	end

	gamepadPresent = UserInputService.GamepadEnabled
	local keyName = gamepadPresent and IGNITION_CONTROLLER.Name or IGNITION_KEYBOARD.Name

	if autoStart then
		promptLabel.Text = "AutoStart enabled"
		promptLabel.Visible = false

debugLog("Startup", "Ignition plugin initialized successfully")
		return
	end

	if isOnValue.Value then
		promptLabel.Text = "Tap <i><stroke color='#000000' thickness='2'><font weight='900'>" .. keyName .. "</font></stroke></i> to turn off."
	elseif accValue.Value then
		promptLabel.Text = "Tap <i><stroke color='#000000' thickness='2'><font weight='900'>" .. keyName .. "</font></stroke></i> to power off, hold to start."
	else
		promptLabel.Text = "Tap <i><stroke color='#000000' thickness='2'><font weight='900'>" .. keyName .. "</font></stroke></i> for ACC, or hold with brake to start."
	end

	promptLabel.Visible = true
end

UserInputService.InputBegan:Connect(onInput)
UserInputService.InputEnded:Connect(onInput)

UserInputService.GamepadConnected:Connect(update)
UserInputService.GamepadDisconnected:Connect(update)
isOnValue.Changed:Connect(update)
startingValue.Changed:Connect(update)
accValue.Changed:Connect(update)
update()
