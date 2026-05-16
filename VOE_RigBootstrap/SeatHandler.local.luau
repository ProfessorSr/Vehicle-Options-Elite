-- SeatHandler.local.luau
-- Disables jump for the local player while seated, adds exit keybind, and seat changing
-- NOTE: Door-based entry/exit restrictions are now handled server-side by VehicleSeatDoorLock

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ACTION_DISABLE_JUMP = "DisableVehicleJump"
local ACTION_EXIT_SEAT = "ExitVehicleSeat"

-- Seat to door mapping (kept for reference, but door checks are now server-side)
local SEAT_TO_DOOR = {
    DriveSeat = "DoorFL",
    FRPassSeat = "DoorFR",
    RLPassSeat = "DoorRL",
    RRPassSeat = "DoorRR",
    RCPassSeat = "DoorRL",
}

-- Get the vehicle model (traverse up to find the root vehicle model)
local function getVehicle()
    local player = Players.LocalPlayer
    if not player or not player.Character then return nil end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or not humanoid.SeatPart then return nil end
    
    local seat = humanoid.SeatPart
    local current = seat.Parent
    
    -- Traverse up the hierarchy to find the vehicle model with VOE_State
    while current do
        if current:FindFirstChild("VOE_State") then
            return current
        end
        current = current.Parent
    end
    
    -- Fallback: return direct parent if no VOE_State found
    return seat.Parent
end

-- Get VOE_State folder
local function getVOEState()
    local vehicle = getVehicle()
    if not vehicle then return nil end
    return vehicle:FindFirstChild("VOE_State")
end

-- Stop the jump completely while seated
local function disableJump(actionName, inputState, inputObj)
    return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction(
    ACTION_DISABLE_JUMP, 
    disableJump, 
    false, 
    Enum.KeyCode.Space, 
    Enum.KeyCode.ButtonA
)

-- Determine which side of the vehicle the seat is on
local function getSeatSide(seat)
    if not seat then return "left" end
    local seatName = seat.Name
    if seatName == "DriveSeat" or seatName == "RLPassSeat" then
        return "left"
    elseif seatName == "FRPassSeat" or seatName == "RRPassSeat" then
        return "right"
    end
    local vehicle = seat.Parent
    if vehicle and vehicle:IsA("Model") and vehicle.PrimaryPart then
        if seat.Position.X > vehicle.PrimaryPart.Position.X then
            return "right"
        end
    end
    return "left"
end

local function setCharacterCollidable(character, collidable)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = collidable
        end
    end
end

local function setCharacterAnchored(character, anchored)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = anchored
        end
    end
end

local function tweenCharacterExit(character, seat)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    -- Use getVehicle() to properly find the vehicle model
    local vehicle = getVehicle()
    if not vehicle then return end
    
    -- Get the vehicle's current CFrame for proper world-space calculation
    local vehicleCF = vehicle:GetPivot()
    
    -- Calculate exit offset relative to vehicle's orientation
    -- 8 studs to the side (left or right), 3 studs to the rear
    local side = getSeatSide(seat)
    local localOffset = Vector3.new(
        side == "left" and -8 or 8,  -- Side offset
        0,                           -- Height (will be adjusted)
        3                            -- Rear offset
    )
    
    -- Transform local offset to world space based on vehicle rotation
    local worldOffset = vehicleCF:VectorToWorldSpace(localOffset)
    
    -- Calculate exit position from seat position
    local seatPosition = seat.CFrame.Position
    local exitPosition = seatPosition + worldOffset + Vector3.new(0, 3, 0) -- Add height to stand on ground
    
    -- Get vehicle's yaw rotation only (ignore pitch/roll for character facing)
    local _, vehicleYaw = vehicleCF:ToEulerAnglesYXZ()
    
    -- Create upright CFrame facing the same yaw direction as the vehicle
    local exitCFrame = CFrame.new(exitPosition) * CFrame.Angles(0, vehicleYaw, 0)
    
    -- Disable collision and anchor character to prevent physics interference
    setCharacterCollidable(character, false)
    setCharacterAnchored(character, true)
    
    -- Unsit the humanoid first
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.Sit = false
    end
    
    -- Small delay to ensure unsit is processed
    task.wait(0.05)
    
    -- Move character to exit position with upright orientation
    root.CFrame = exitCFrame
    
    -- Re-enable physics after a short delay
    task.wait(0.1)
    setCharacterAnchored(character, false)
    
    -- Re-enable collision after character is clear
    task.spawn(function()
        task.wait(1)
        setCharacterCollidable(character, true)
    end)
end

-- Show message to player
local function showMessage(text, duration)
    duration = duration or 2
    local player = Players.LocalPlayer
    if not player or not player:FindFirstChild("PlayerGui") then return end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "VehicleMessageGui"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 0.1, 0)
    label.Position = UDim2.new(0.25, 0, 0.8, 0)
    label.BackgroundTransparency = 0.3
    label.BackgroundColor3 = Color3.new(0.2, 0, 0)
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextScaled = true
    label.Text = text
    label.Parent = screenGui
    screenGui.Parent = player.PlayerGui
    
    task.spawn(function()
        task.wait(duration)
        if screenGui then screenGui:Destroy() end
    end)
end

-- Exit seat function
-- NOTE: Door check is now handled server-side
local function tryExitSeat()
    local player = Players.LocalPlayer
    if not player then return end
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.SeatPart then
        local seat = humanoid.SeatPart
        humanoid.Sit = false
        task.defer(function()
            task.wait(0.05)
            tweenCharacterExit(character, seat)
        end)
    end
end

-- Change seat function
local function changeSeat(targetSeatName)
    print("[SeatHandler] changeSeat called for: " .. targetSeatName)
    
    local player = Players.LocalPlayer
    if not player or not player.Character then 
        print("[SeatHandler] No player or character")
        return 
    end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then 
        print("[SeatHandler] No humanoid")
        return 
    end
    
    local currentSeat = humanoid.SeatPart
    if not currentSeat then 
        print("[SeatHandler] Not currently seated")
        return 
    end
    
    -- Don't change to the same seat
    if currentSeat.Name == targetSeatName then
        showMessage("Already in " .. targetSeatName)
        return
    end
    
    -- Use getVehicle() to properly find the vehicle model
    local vehicle = getVehicle()
    if not vehicle then 
        print("[SeatHandler] No vehicle found")
        return 
    end
    
    -- Find the VOE_State folder and RemoteEvent
    local voeState = vehicle:FindFirstChild("VOE_State")
    if not voeState then
        print("[SeatHandler] VOE_State not found")
        showMessage("Seat change not available")
        return
    end
    
    local remoteEvent = voeState:FindFirstChild("SeatChangeRequest")
    if not remoteEvent then
        print("[SeatHandler] SeatChangeRequest RemoteEvent not found")
        showMessage("Seat change not available")
        return
    end
    
    -- Check if target seat exists
    local targetSeat = vehicle:FindFirstChild(targetSeatName, true)
    if not targetSeat or not (targetSeat:IsA("Seat") or targetSeat:IsA("VehicleSeat")) then
        showMessage("Seat not found: " .. targetSeatName)
        print("[SeatHandler] Target seat not found: " .. targetSeatName)
        return
    end
    
    -- Check if target seat is empty
    if targetSeat.Occupant then
        showMessage(targetSeatName .. " is occupied!")
        return
    end
    
    -- Fire the server event
    print("[SeatHandler] Firing server event for seat change to: " .. targetSeatName)
    remoteEvent:FireServer(targetSeatName)
end

-- Bind exit key (3 only)
ContextActionService:BindAction(
    ACTION_EXIT_SEAT,
    function(actionName, inputState, inputObj)
        if inputState == Enum.UserInputState.Begin then
            tryExitSeat()
        end
        return Enum.ContextActionResult.Sink
    end,
    false,
    Enum.KeyCode.Three
)

-- Bind seat change keys (6-0 to avoid conflict with spotlights)
local SEAT_KEYS = {
    [Enum.KeyCode.Six] = "DriveSeat",
    [Enum.KeyCode.Seven] = "FRPassSeat",
    [Enum.KeyCode.Eight] = "RLPassSeat",
    [Enum.KeyCode.Nine] = "RRPassSeat",
    [Enum.KeyCode.Zero] = "RCPassSeat",
}

for keyCode, seatName in pairs(SEAT_KEYS) do
    ContextActionService:BindAction(
        "ChangeSeat_" .. seatName,
        function(actionName, inputState, inputObj)
            if inputState == Enum.UserInputState.Begin then
                changeSeat(seatName)
            end
            return Enum.ContextActionResult.Sink
        end,
        false,
        keyCode
    )
end

-- Clean up when the script is destroyed
script.Destroying:Connect(function()
    ContextActionService:UnbindAction(ACTION_DISABLE_JUMP)
    ContextActionService:UnbindAction(ACTION_EXIT_SEAT)
    for keyCode, seatName in pairs(SEAT_KEYS) do
        ContextActionService:UnbindAction("ChangeSeat_" .. seatName)
    end
end)

-- Show seat change hints
local function showSeatHints()
    local player = Players.LocalPlayer
    if not player or not player:FindFirstChild("PlayerGui") then return end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SeatHintsGui"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.3, 0, 0.25, 0)
    frame.Position = UDim2.new(0, 10, 0.7, 0)
    frame.BackgroundTransparency = 0.5
    frame.BackgroundColor3 = Color3.new(0, 0, 0)
    frame.Parent = screenGui
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.2, 0)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextScaled = true
    title.Text = "Seat Controls"
    title.Parent = frame
    
    local hints = {
        "3 - Exit Vehicle",
        "6 - Driver Seat",
        "7 - Front Passenger",
        "8 - Rear Left",
        "9 - Rear Right",
        "0 - Rear Center",
    }
    
    for i, hint in ipairs(hints) do
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0.13, 0)
        label.Position = UDim2.new(0, 0, 0.2 + (i - 1) * 0.13, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextScaled = true
        label.Text = hint
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame
    end
    
    screenGui.Parent = player.PlayerGui
    
    -- Auto-hide after 5 seconds
    task.spawn(function()
        task.wait(5)
        if screenGui then screenGui:Destroy() end
    end)
end

showSeatHints()