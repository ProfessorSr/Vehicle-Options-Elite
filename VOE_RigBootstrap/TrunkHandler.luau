--[[
	VOE_TrunkHandler
	Out-of-seat handler for Trunk click interaction
	
	This module runs when the vehicle spawns (before anyone sits)
	and handles:
	- Creating state value in VOE_State
	- Listening for state changes
	- Moving the trunk hinge
]]

local TrunkHandler = {}

--====================================================================
-- TRUNK CONFIGURATION
-- Edit these values to customize trunk behavior
-- OpenAngle: degrees the trunk opens (negative = opposite direction)
-- CloseAngle: degrees when closed (usually 0)
-- OpenSpeed: angular speed for hinge movement
-- OpenTorque: servo torque for hinge movement
--====================================================================

TrunkHandler.Preset = {
	OpenAngle = 65,
	CloseAngle = 0,
	OpenSpeed = 3.0,
	OpenTorque = 20000,
}

-- Default configuration (fallback)
local DEFAULT_OPEN_ANGLE = 65
local DEFAULT_CLOSE_ANGLE = 0
local DEFAULT_OPEN_SPEED = 3.0
local DEFAULT_OPEN_TORQUE = 20000

function TrunkHandler.Initialize(vehicle, voeState)
	if not vehicle or not voeState then
		warn("[TrunkHandler] Invalid vehicle or voeState")
		return
	end
	
	-- Find trunk root part by tag
	local trunkRoot = nil
	for _, inst in ipairs(game:GetService("CollectionService"):GetTagged("VOE_Trunk_Root")) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(vehicle) then
			trunkRoot = inst
			break
		end
	end
	
	if not trunkRoot then
		print("[TrunkHandler] No trunk root found")
		return
	end
	
	-- Find the hinge created by VOE_RigBootstrap
	local hinge = trunkRoot:FindFirstChild("VOE_Hinge_VOE_Trunk")
	if not hinge or not hinge:IsA("HingeConstraint") then
		-- Fallback: find any HingeConstraint
		for _, child in ipairs(trunkRoot:GetChildren()) do
			if child:IsA("HingeConstraint") then
				hinge = child
				break
			end
		end
	end
	
	if not hinge then
		warn("[TrunkHandler] No hinge found on trunk root")
		return
	end
	
	-- Get angles from part attributes first, then preset, then defaults
	local openAngle = tonumber(trunkRoot:GetAttribute("VOE_OpenAngle")) 
		or tonumber(TrunkHandler.Preset.OpenAngle) 
		or DEFAULT_OPEN_ANGLE
	local closeAngle = tonumber(trunkRoot:GetAttribute("VOE_CloseAngle")) 
		or tonumber(TrunkHandler.Preset.CloseAngle) 
		or DEFAULT_CLOSE_ANGLE
	
	-- Configure hinge speed and torque
	hinge.AngularSpeed = tonumber(trunkRoot:GetAttribute("VOE_OpenSpeed")) 
		or tonumber(TrunkHandler.Preset.OpenSpeed) 
		or DEFAULT_OPEN_SPEED
	hinge.ServoMaxTorque = tonumber(trunkRoot:GetAttribute("VOE_OpenTorque")) 
		or tonumber(TrunkHandler.Preset.OpenTorque) 
		or DEFAULT_OPEN_TORQUE
	hinge.TargetAngle = closeAngle
	
	-- Create or get state value
	local stateValue = voeState:FindFirstChild("Trunk")
	if not stateValue then
		stateValue = Instance.new("BoolValue")
		stateValue.Name = "Trunk"
		stateValue.Value = false
		stateValue.Parent = voeState
	end
	stateValue:SetAttribute("VOE_Owner", "TrunkHandler")
	stateValue:SetAttribute("VOE_Type", "State")
	
	-- Function to apply state
	local function applyState()
		local isOpen = stateValue.Value
		hinge.TargetAngle = isOpen and openAngle or closeAngle
		print("[TrunkHandler] Setting hinge to", isOpen and "OPEN" or "CLOSED", "angle:", hinge.TargetAngle)
	end
	
	-- Listen for state changes
	stateValue.Changed:Connect(applyState)
	
	-- Apply initial state
	applyState()
	
	print("[TrunkHandler] Initialized successfully: OpenAngle=" .. openAngle .. ", CloseAngle=" .. closeAngle)
end

return TrunkHandler