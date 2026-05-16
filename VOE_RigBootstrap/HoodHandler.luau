--[[
	VOE_HoodHandler
	Out-of-seat handler for Hood click interaction
	
	This module runs when the vehicle spawns (before anyone sits)
	and handles:
	- Creating state value in VOE_State
	- Listening for state changes
	- Moving the hood hinge
]]

local HoodHandler = {}

--====================================================================
-- HOOD CONFIGURATION
-- Edit these values to customize hood behavior
-- OpenAngle: degrees the hood opens (negative = opposite direction)
-- CloseAngle: degrees when closed (usually 0)
-- OpenSpeed: angular speed for hinge movement
-- OpenTorque: servo torque for hinge movement
--====================================================================

HoodHandler.Preset = {
	OpenAngle = -65,
	CloseAngle = 0,
	OpenSpeed = 3.0,
	OpenTorque = 20000,
}

--====================================================================
-- HOOD LOCK CONFIGURATION
-- Hood requires unlock before clicking to open (like a real car)
-- HoodUnlocked state is stored in VOE_State and persists when player exits
--====================================================================

HoodHandler.LockConfig = {
	RequiresUnlock = true,  -- Set to false to disable lock system
}

-- Default configuration (fallback)
local DEFAULT_OPEN_ANGLE = -65
local DEFAULT_CLOSE_ANGLE = 0
local DEFAULT_OPEN_SPEED = 3.0
local DEFAULT_OPEN_TORQUE = 20000

function HoodHandler.Initialize(vehicle, voeState)
	if not vehicle or not voeState then
		warn("[HoodHandler] Invalid vehicle or voeState")
		return
	end
	
	-- Find hood root part by tag
	local hoodRoot = nil
	for _, inst in ipairs(game:GetService("CollectionService"):GetTagged("VOE_Hood_Root")) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(vehicle) then
			hoodRoot = inst
			break
		end
	end
	
	if not hoodRoot then
		print("[HoodHandler] No hood root found")
		return
	end
	
	-- Find the hinge created by VOE_RigBootstrap
	local hinge = hoodRoot:FindFirstChild("VOE_Hinge_VOE_Hood")
	if not hinge or not hinge:IsA("HingeConstraint") then
		-- Fallback: find any HingeConstraint
		for _, child in ipairs(hoodRoot:GetChildren()) do
			if child:IsA("HingeConstraint") then
				hinge = child
				break
			end
		end
	end
	
	if not hinge then
		warn("[HoodHandler] No hinge found on hood root")
		return
	end
	
	-- Get angles from part attributes first, then preset, then defaults
	local openAngle = tonumber(hoodRoot:GetAttribute("VOE_OpenAngle")) 
		or tonumber(HoodHandler.Preset.OpenAngle) 
		or DEFAULT_OPEN_ANGLE
	local closeAngle = tonumber(hoodRoot:GetAttribute("VOE_CloseAngle")) 
		or tonumber(HoodHandler.Preset.CloseAngle) 
		or DEFAULT_CLOSE_ANGLE
	
	-- Configure hinge speed and torque
	hinge.AngularSpeed = tonumber(hoodRoot:GetAttribute("VOE_OpenSpeed")) 
		or tonumber(HoodHandler.Preset.OpenSpeed) 
		or DEFAULT_OPEN_SPEED
	hinge.ServoMaxTorque = tonumber(hoodRoot:GetAttribute("VOE_OpenTorque")) 
		or tonumber(HoodHandler.Preset.OpenTorque) 
		or DEFAULT_OPEN_TORQUE
	hinge.TargetAngle = closeAngle
	
	--====================================================================
	-- Create state values
	--====================================================================
	
	-- Hood open/closed state
	local stateValue = voeState:FindFirstChild("Hood")
	if not stateValue then
		stateValue = Instance.new("BoolValue")
		stateValue.Name = "Hood"
		stateValue.Value = false
		stateValue.Parent = voeState
	end
	stateValue:SetAttribute("VOE_Owner", "HoodHandler")
	stateValue:SetAttribute("VOE_Type", "State")
	
	-- Hood locked/unlocked state (for realistic hood release system)
	local unlockedValue = voeState:FindFirstChild("HoodUnlocked")
	if not unlockedValue then
		unlockedValue = Instance.new("BoolValue")
		unlockedValue.Name = "HoodUnlocked"
		unlockedValue.Value = false
		unlockedValue.Parent = voeState
	end
	unlockedValue:SetAttribute("VOE_Owner", "HoodHandler")
	unlockedValue:SetAttribute("VOE_Type", "State")
	
	--====================================================================
	-- State change handlers
	--====================================================================
	
	-- Function to apply state (move hinge)
	local function applyState()
		local isOpen = stateValue.Value
		hinge.TargetAngle = isOpen and openAngle or closeAngle
		print("[HoodHandler] Setting hinge to", isOpen and "OPEN" or "CLOSED", "angle:", hinge.TargetAngle)
		
		-- Lock the hood when it closes (realistic behavior)
		if not isOpen and HoodHandler.LockConfig.RequiresUnlock then
			unlockedValue.Value = false
			print("[HoodHandler] Hood closed - locking")
		end
	end
	
	-- Listen for state changes
	stateValue.Changed:Connect(applyState)
	
	-- Apply initial state
	applyState()
	
	print("[HoodHandler] Initialized successfully: OpenAngle=" .. openAngle .. ", CloseAngle=" .. closeAngle .. ", RequiresUnlock=" .. tostring(HoodHandler.LockConfig.RequiresUnlock))
end

return HoodHandler