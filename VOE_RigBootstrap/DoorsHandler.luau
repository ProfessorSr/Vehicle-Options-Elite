--[[
	VOE_DoorsHandler
	Out-of-seat handler for Doors click interaction
	
	This module runs when the vehicle spawns (before anyone sits)
	and handles:
	- Creating state values in VOE_State for each door
	- Listening for state changes
	- Moving the door hinges
]]

local DoorsHandler = {}

-- Door roles to handle
local DOOR_ROLES = {"DoorFL", "DoorFR", "DoorRL", "DoorRR", "DoorSL", "DoorSR"}

--====================================================================
-- PER-DOOR CONFIGURATION
-- Edit these values to customize each door's behavior
-- OpenAngle: degrees the door opens (negative = opposite direction)
-- CloseAngle: degrees when closed (usually 0)
-- OpenSpeed: angular speed for hinge movement
-- OpenTorque: servo torque for hinge movement
--====================================================================

DoorsHandler.Presets = {
	DoorFL = {
		OpenAngle = 65,
		CloseAngle = 0,
		OpenSpeed = 3.0,
		OpenTorque = 20000,
	},
	DoorFR = {
		OpenAngle = 65,
		CloseAngle = 0,
		OpenSpeed = 3.0,
		OpenTorque = 20000,
	},
	DoorRL = {
		OpenAngle = -65,
		CloseAngle = 0,
		OpenSpeed = 3.0,
		OpenTorque = 20000,
	},
	DoorRR = {
		OpenAngle = 65,
		CloseAngle = 0,
		OpenSpeed = 3.0,
		OpenTorque = 20000,
	},
	DoorSL = {
		OpenAngle = 0,
		CloseAngle = 0,
		OpenSpeed = 3.0,
		OpenTorque = 20000,
	},
	DoorSR = {
		OpenAngle = 0,
		CloseAngle = 0,
		OpenSpeed = 3.0,
		OpenTorque = 20000,
	},
}

--====================================================================
-- CHILD LOCK CONFIGURATION
-- When enabled, rear doors can only be opened from outside (player not seated)
-- Set to false to allow opening from inside or outside
--====================================================================

DoorsHandler.ChildLock = false  -- Set to false to disable child lock

-- Rear doors that are affected by child lock
local REAR_DOORS = {DoorRL = true, DoorRR = true}

-- Check if a door role is a rear door
function DoorsHandler.IsRearDoor(roleName)
	return REAR_DOORS[roleName] == true
end

-- Check if child lock is enabled for a specific door
function DoorsHandler.IsChildLocked(roleName)
	return DoorsHandler.ChildLock and DoorsHandler.IsRearDoor(roleName)
end

-- Default configuration (fallback if no preset found)
local DEFAULT_OPEN_ANGLE = 50
local DEFAULT_CLOSE_ANGLE = 0
local DEFAULT_OPEN_SPEED = 3.0
local DEFAULT_OPEN_TORQUE = 20000

function DoorsHandler.Initialize(vehicle, voeState)
	if not vehicle or not voeState then
		warn("[DoorsHandler] Invalid vehicle or voeState")
		return
	end
	
	local CollectionService = game:GetService("CollectionService")
	
	for _, roleName in ipairs(DOOR_ROLES) do
		local rootTag = "VOE_" .. roleName .. "_Root"
		local roots = CollectionService:GetTagged(rootTag)
		
		for _, rootPart in ipairs(roots) do
			if not rootPart:IsA("BasePart") or not rootPart:IsDescendantOf(vehicle) then
				continue
			end
			
			-- Find the hinge created by VOE_RigBootstrap
			local hingeName = "VOE_Hinge_VOE_" .. roleName
			local hinge = rootPart:FindFirstChild(hingeName)
			
			if not hinge or not hinge:IsA("HingeConstraint") then
				-- Fallback: find any HingeConstraint
				for _, child in ipairs(rootPart:GetChildren()) do
					if child:IsA("HingeConstraint") then
						hinge = child
						break
					end
				end
			end
			
			if hinge then
				-- Get preset for this door role
				local preset = DoorsHandler.Presets[roleName] or {}
				
				-- Get angles from part attributes first, then preset, then defaults
				local openAngle = tonumber(rootPart:GetAttribute("VOE_OpenAngle")) 
					or tonumber(preset.OpenAngle) 
					or DEFAULT_OPEN_ANGLE
				local closeAngle = tonumber(rootPart:GetAttribute("VOE_CloseAngle")) 
					or tonumber(preset.CloseAngle) 
					or DEFAULT_CLOSE_ANGLE
				
				-- Configure hinge speed and torque
				hinge.AngularSpeed = tonumber(rootPart:GetAttribute("VOE_OpenSpeed")) 
					or tonumber(preset.OpenSpeed) 
					or DEFAULT_OPEN_SPEED
				hinge.ServoMaxTorque = tonumber(rootPart:GetAttribute("VOE_OpenTorque")) 
					or tonumber(preset.OpenTorque) 
					or DEFAULT_OPEN_TORQUE
				hinge.TargetAngle = closeAngle
				
				-- Create or get state value
				local stateValue = voeState:FindFirstChild(roleName)
				if not stateValue then
					stateValue = Instance.new("BoolValue")
					stateValue.Name = roleName
					stateValue.Value = false
					stateValue.Parent = voeState
				end
				stateValue:SetAttribute("VOE_Owner", "DoorsHandler")
				stateValue:SetAttribute("VOE_Type", "State")
				
				-- Function to apply state (capture variables)
				local function applyState()
					local isOpen = stateValue.Value
					hinge.TargetAngle = isOpen and openAngle or closeAngle
				end
				
				-- Listen for state changes
				stateValue.Changed:Connect(applyState)
				
				-- Apply initial state
				applyState()
				
				print("[DoorsHandler] Initialized " .. roleName .. ": OpenAngle=" .. openAngle .. ", CloseAngle=" .. closeAngle)
			end
		end
	end
	
	print("[DoorsHandler] Initialized successfully")
end

return DoorsHandler