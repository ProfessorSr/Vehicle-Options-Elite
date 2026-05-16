--[[
	VOE_SpotlightsHandler
	Server-side setup for spotlight hinge rigging.

	This module runs when the vehicle spawns and handles:
	- Finding spotlight hinges created by VOE_RigBootstrap
	- Applying default servo speed/torque
	- Creating VOE_State values for spotlight power and hinge angles
	- Letting server-side angle values drive hinge TargetAngle
]]

local SpotlightsHandler = {}

local SIDES = {"Left", "Right"}
local SEGMENTS = {"Base", "Arm", "Lamp"}

SpotlightsHandler.Preset = {
	RotationSpeed = 5,
	RotationTorque = 15000,
	Base = {
		MinAngle = -180,
		MaxAngle = 180,
	},
	Arm = {
		MinAngle = -180,
		MaxAngle = 180,
	},
	Lamp = {
		MinAngle = -45,
		MaxAngle = 45,
	},
}

local function ensureValue(container, name, className, defaultValue)
	local existing = container:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end

	local value = Instance.new(className)
	value.Name = name
	value.Parent = container
	value:SetAttribute("VOE_Owner", "SpotlightsHandler")
	value:SetAttribute("VOE_Type", "State")

	if className == "BoolValue" then
		value.Value = defaultValue == true
	elseif className == "NumberValue" then
		value.Value = tonumber(defaultValue) or 0
	end

	return value
end

local function findSpotlightHinge(vehicle, side, segment)
	local hingeName = "VOE_Spotlight_" .. side .. "_" .. segment .. "Hinge"
	for _, inst in ipairs(vehicle:GetDescendants()) do
		if inst.Name == hingeName and inst:IsA("HingeConstraint") then
			return inst
		end
	end
	return nil
end

local function clampAngle(angle, minAngle, maxAngle)
	if minAngle > maxAngle then
		minAngle, maxAngle = maxAngle, minAngle
	end
	return math.clamp(angle, minAngle, maxAngle)
end

local function getMotionConfig(hinge, segment)
	local part = hinge and hinge.Parent
	local preset = SpotlightsHandler.Preset[segment] or {}
	return {
		MinAngle = tonumber(part and part:GetAttribute("VOE_MinAngle"))
			or tonumber(part and part:GetAttribute("VOE_" .. segment .. "MinAngle"))
			or tonumber(preset.MinAngle)
			or -180,
		MaxAngle = tonumber(part and part:GetAttribute("VOE_MaxAngle"))
			or tonumber(part and part:GetAttribute("VOE_" .. segment .. "MaxAngle"))
			or tonumber(preset.MaxAngle)
			or 180,
		Speed = tonumber(part and part:GetAttribute("VOE_OpenSpeed"))
			or tonumber(SpotlightsHandler.Preset.RotationSpeed)
			or 5,
		Torque = tonumber(part and part:GetAttribute("VOE_OpenTorque"))
			or tonumber(SpotlightsHandler.Preset.RotationTorque)
			or 15000,
	}
end

function SpotlightsHandler.Initialize(vehicle, voeState)
	if not vehicle or not voeState then
		warn("[SpotlightsHandler] Invalid vehicle or voeState")
		return
	end

	for _, side in ipairs(SIDES) do
		ensureValue(voeState, "Spotlight" .. side, "BoolValue", false)

		for _, segment in ipairs(SEGMENTS) do
			local hinge = findSpotlightHinge(vehicle, side, segment)
			local angleValue = ensureValue(voeState, "Spotlight" .. side .. segment .. "Angle", "NumberValue", 0)

			if hinge then
				local motion = getMotionConfig(hinge, segment)
				hinge.ActuatorType = Enum.ActuatorType.Servo
				hinge.AngularSpeed = motion.Speed
				hinge.ServoMaxTorque = motion.Torque
				hinge.LimitsEnabled = false
				angleValue.Value = clampAngle(angleValue.Value, motion.MinAngle, motion.MaxAngle)
				hinge.TargetAngle = angleValue.Value

				local applying = false
				angleValue.Changed:Connect(function()
					if applying then return end
					local clamped = clampAngle(angleValue.Value, motion.MinAngle, motion.MaxAngle)
					if clamped ~= angleValue.Value then
						applying = true
						angleValue.Value = clamped
						applying = false
					end
					if hinge.Parent then
						hinge.TargetAngle = clamped
					end
				end)

				print("[SpotlightsHandler] Initialized " .. side .. " " .. segment .. " hinge: Range=" .. motion.MinAngle .. ".." .. motion.MaxAngle)
			else
				warn("[SpotlightsHandler] Missing " .. side .. " " .. segment .. " hinge")
			end
		end
	end

	print("[SpotlightsHandler] Initialized successfully")
end

return SpotlightsHandler
