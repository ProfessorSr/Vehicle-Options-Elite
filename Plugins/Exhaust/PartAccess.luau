--[[
	Plugin: Exhaust
	Purpose: Part access utilities for Exhaust plugin (tagged instance and part resolution).
	Last updated: 2026-03-21
]]

local PartAccess = {}
PartAccess.__index = PartAccess

function PartAccess.new(collectionService, vehicleModel)
	return setmetatable({
		CollectionService = collectionService,
		VehicleModel = vehicleModel,
	}, PartAccess)
end

function PartAccess:taggedInstances(tagName)
	local out = {}
	for _, inst in ipairs(self.CollectionService:GetTagged(tagName)) do
		if (inst:IsA("BasePart") or inst:IsA("Model")) and inst:IsDescendantOf(self.VehicleModel) then
			table.insert(out, inst)
		end
	end
	return out
end

function PartAccess.resolveBasePart(inst)
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

function PartAccess.resolveRootPart(inst)
	if inst:IsA("BasePart") then return inst end
	if not inst:IsA("Model") then return nil end
	local pivot = inst:FindFirstChild("VOE_HingePivot", true)
	if pivot and pivot:IsA("Attachment") and pivot.Parent and pivot.Parent:IsA("BasePart") then
		return pivot.Parent
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("VOE_IsHingeRoot") == true then
			return d
		end
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") and string.find(string.lower(d.Name), "hinge", 1, true) then
			return d
		end
	end
	return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
end

return PartAccess
