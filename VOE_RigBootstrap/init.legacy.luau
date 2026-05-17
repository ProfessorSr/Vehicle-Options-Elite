local CollectionService = game:GetService("CollectionService")

local vehicleModel = script.Parent
local bodyModel = vehicleModel:WaitForChild("Body")
local driveSeat = vehicleModel:WaitForChild("DriveSeat")

--====================================================================
-- WAIT FOR A-CHASSIS
--====================================================================

if vehicleModel:GetAttribute("AChassisReady") ~= true then
	vehicleModel:GetAttributeChangedSignal("AChassisReady"):Wait()
	while vehicleModel:GetAttribute("AChassisReady") ~= true do
		task.wait()
	end
end

print("[VOE_RigBootstrap] A-Chassis ready, starting rig setup...")

--====================================================================
-- CREATE VOE_STATE FOLDER
--====================================================================

local voeState = vehicleModel:FindFirstChild("VOE_State")
if not voeState then
	voeState = Instance.new("Folder")
	voeState.Name = "VOE_State"
	voeState.Parent = vehicleModel
	print("[VOE_RigBootstrap] Created VOE_State folder")
end

--====================================================================
-- PERSISTENCE ATTRIBUTES (ensure attributes exist on vehicle)
-- These attributes are created at rig bootstrap so they're available
-- immediately when the vehicle spawns (before players sit in seats).
--====================================================================

local function ensureNumberAttr(name, default)
	if vehicleModel:GetAttribute(name) == nil then
		vehicleModel:SetAttribute(name, default)
	end
end

local function ensureBoolAttr(name, default)
	if vehicleModel:GetAttribute(name) == nil then
		vehicleModel:SetAttribute(name, default)
	end
end

-- Engine-related (basic defaults; Engine plugin will override on setup)
ensureNumberAttr("EngineWear", 100)
ensureNumberAttr("MaintenanceMilesRemaining", 5000)
ensureNumberAttr("CoolantLevel", 100)
ensureNumberAttr("EngineTemp", 80)
ensureNumberAttr("OilPressure", 24)
ensureBoolAttr("CheckEngine", false)
ensureNumberAttr("CoolantTemp", 180)
ensureNumberAttr("OilLevel", 100)
ensureNumberAttr("BatteryCondition", 100)
ensureNumberAttr("BatteryPercent", 100)
ensureNumberAttr("BatteryVoltage", 12.6)
ensureBoolAttr("BatteryLow", false)
ensureBoolAttr("AlternatorOn", false)
ensureNumberAttr("CoolantPressure", 10)
ensureBoolAttr("CoolantWarning", false)
ensureBoolAttr("EngineLimpMode", false)
ensureBoolAttr("MaintenanceDue", false)
ensureBoolAttr("OilPressureWarning", false)
ensureBoolAttr("OilLight", false)
ensureBoolAttr("CoolantLight", false)

-- Fuel-related (basic defaults; Fuel plugin will override on setup)
ensureNumberAttr("FuelGallons", 0)
ensureNumberAttr("FuelCapacityGallons", 18)
ensureNumberAttr("FuelLevel", 0)
ensureBoolAttr("FuelEmpty", false)
ensureBoolAttr("FuelLimpMode", false)


--====================================================================
-- HELPERS
--====================================================================

local function breakWelds(part)
	for _, obj in ipairs(part:GetDescendants()) do
		if obj:IsA("Weld") or obj:IsA("WeldConstraint") or obj:IsA("Motor6D") then
			obj:Destroy()
		end
	end
end

local function weld(part0, part1)
	if part0 == part1 then return end
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part0
end

local function getTagged(tag)
	local results = {}
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(bodyModel) then
			table.insert(results, inst)
		end
	end
	return results
end

--====================================================================
-- WINDOW SET
--====================================================================

local WINDOW_TAGS = {
	"VOE_WindowFL_Root","VOE_WindowFR_Root","VOE_WindowRL_Root","VOE_WindowRR_Root"
}

local function getWindowRoots()
	local roots = {}

	for _, tag in ipairs(WINDOW_TAGS) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			if inst:IsA("BasePart") and inst:IsDescendantOf(bodyModel) then
				table.insert(roots, inst)
			end
		end
	end

	return roots
end

local function buildWindowSet(windowRoots)
	local set = {}

	for _, root in ipairs(windowRoots) do
		set[root] = true
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") then
				set[d] = true
			end
		end
	end

	-- Include VOE_WindowXX_Part tagged parts (they're siblings, not descendants)
	for _, tag in ipairs(WINDOW_TAGS) do
		local prefix = string.match(tag, "VOE_(Window%a%a)_Root")
		if prefix then
			local partTag = "VOE_" .. prefix .. "_Part"
			for _, p in ipairs(getTagged(partTag)) do
				set[p] = true
				for _, d in ipairs(p:GetDescendants()) do
					if d:IsA("BasePart") then
						set[d] = true
					end
				end
			end
		end
	end

	return set
end

local function breakExternalWelds(partSet)
	-- Collect first, destroy second to avoid iteration-over-mutated-tree issues
	local toDestroy = {}
	for _, inst in ipairs(vehicleModel:GetDescendants()) do
		if inst:IsA("Weld") or inst:IsA("WeldConstraint") or inst:IsA("Motor6D") then
			local p0, p1 = inst.Part0, inst.Part1
			if p0 and p1 then
				local in0 = partSet[p0] == true
				local in1 = partSet[p1] == true

				if in0 ~= in1 then
					table.insert(toDestroy, inst)
				end
			end
		end
	end
	for _, inst in ipairs(toDestroy) do
		inst:Destroy()
	end
end

local function breakWeldsTouching(partSet)
	local toDestroy = {}
	for _, inst in ipairs(vehicleModel:GetDescendants()) do
		if inst:IsA("Weld") or inst:IsA("WeldConstraint") or inst:IsA("Motor6D") then
			local p0, p1 = inst.Part0, inst.Part1
			if (p0 and partSet[p0]) or (p1 and partSet[p1]) then
				table.insert(toDestroy, inst)
			end
		end
	end
	for _, inst in ipairs(toDestroy) do
		inst:Destroy()
	end
end

local function addPartAndDescendants(partSet, part)
	if not part or not part:IsA("BasePart") then return end
	partSet[part] = true
	for _, descendant in ipairs(part:GetDescendants()) do
		if descendant:IsA("BasePart") then
			partSet[descendant] = true
		end
	end
end

local function buildTaggedPartSet(tag)
	local set = {}
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(bodyModel) then
			addPartAndDescendants(set, inst)
		end
	end
	return set
end

local function getFirstTaggedPart(tag)
	if not tag or tag == "" then return nil end
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(bodyModel) then
			return inst
		end
	end
	return nil
end

local function findAttachmentInRoot(part, attachmentName)
	if not part or not part:IsA("BasePart") or not attachmentName or attachmentName == "" then
		return nil
	end
	local attachment = part:FindFirstChild(attachmentName)
	if attachment and attachment:IsA("Attachment") then
		return attachment
	end
	for _, descendant in ipairs(part:GetDescendants()) do
		if descendant:IsA("Attachment") and descendant.Name == attachmentName then
			return descendant
		end
	end
	return nil
end

local function findAttachmentByName(name)
	for _, inst in ipairs(vehicleModel:GetDescendants()) do
		if inst:IsA("Attachment") and inst.Name == name then
			return inst
		end
	end
	return nil
end

local function isHingePivot(inst)
	return inst
		and inst:IsA("Attachment")
		and (inst.Name == "VOE_HingePivot" or CollectionService:HasTag(inst, "VOE_HingePivot"))
end

local function getNearestVehicleContainer(part)
	local current = part and part.Parent
	while current and current ~= bodyModel and current ~= vehicleModel do
		if current:IsA("Model") or current:IsA("Folder") then
			return current
		end
		current = current.Parent
	end
	return part
end

local function collectPartsFromContainer(container)
	local parts = {}
	if not container then return parts end
	if container:IsA("BasePart") then
		table.insert(parts, container)
		return parts
	end
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:IsDescendantOf(bodyModel) then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function inferSpotlightSegment(attachment)
	local current = attachment
	while current and current ~= bodyModel and current ~= vehicleModel do
		local name = string.lower(current.Name or "")
		if name:find("base") or name:find("mount") then
			return "Base"
		elseif name:find("arm") or name:find("shaft") or name:find("stalk") then
			return "Arm"
		elseif name:find("lamp") or name:find("head") or name:find("light") then
			return "Lamp"
		end
		current = current.Parent
	end
	return nil
end

local function collectSpotlightHingePivots(spec)
	local bySegment = {}
	local candidates = {}
	local seenParts = {}
	local sideAliases = spec.Id == "Left" and {"left", "lh", "driver"} or {"right", "rh", "passenger"}

	for _, lightPart in ipairs(getTagged(spec.LightTag)) do
		for _, part in ipairs(collectPartsFromContainer(getNearestVehicleContainer(lightPart))) do
			if not seenParts[part] then
				seenParts[part] = true
				table.insert(candidates, part)
			end
		end
	end

	for _, inst in ipairs(vehicleModel:GetDescendants()) do
		if isHingePivot(inst) and inst.Parent and inst.Parent:IsA("BasePart") then
			local path = string.lower(inst:GetFullName())
			local matchesSide = false
			for _, alias in ipairs(sideAliases) do
				if path:find(alias) then
					matchesSide = true
					break
				end
			end
			if path:find("spotlight") and matchesSide then
				if not seenParts[inst.Parent] then
					seenParts[inst.Parent] = true
					table.insert(candidates, inst.Parent)
				end
			end
		end
	end

	for _, explicit in ipairs({
		{Segment = "Base", Name = spec.BaseAttachment},
		{Segment = "Arm", Name = spec.ArmAttachment},
		{Segment = "Lamp", Name = spec.LampAttachment},
	}) do
		local attachment = findAttachmentByName(explicit.Name)
		if attachment and attachment.Parent and attachment.Parent:IsA("BasePart") then
			bySegment[explicit.Segment] = attachment
			if not seenParts[attachment.Parent] then
				seenParts[attachment.Parent] = true
				table.insert(candidates, attachment.Parent)
			end
		end
	end

	local genericPivots = {}
	for _, part in ipairs(candidates) do
		for _, descendant in ipairs(part:GetDescendants()) do
			if isHingePivot(descendant) then
				table.insert(genericPivots, descendant)
				local segment = inferSpotlightSegment(descendant)
				if segment and not bySegment[segment] then
					bySegment[segment] = descendant
				end
			end
		end
	end

	table.sort(genericPivots, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)

	for _, segment in ipairs({"Base", "Arm", "Lamp"}) do
		if not bySegment[segment] then
			for _, pivot in ipairs(genericPivots) do
				local alreadyUsed = false
				for _, assigned in pairs(bySegment) do
					if assigned == pivot then
						alreadyUsed = true
						break
					end
				end
				if not alreadyUsed then
					bySegment[segment] = pivot
					break
				end
			end
		end
	end

	return bySegment, candidates
end

local function createServoHinge(movingPart, pivotAttachment, anchorPart, hingeName, driveName)
	if not movingPart or not movingPart:IsA("BasePart") then return nil end
	if not pivotAttachment or not pivotAttachment:IsA("Attachment") then return nil end
	if not anchorPart or not anchorPart:IsA("BasePart") then return nil end
	if movingPart == anchorPart then return nil end

	local existing = movingPart:FindFirstChild(hingeName)
	if existing and existing:IsA("HingeConstraint") then
		return existing
	end

	local worldCF = pivotAttachment.WorldCFrame
	local driveAttachment = Instance.new("Attachment")
	driveAttachment.Name = driveName
	driveAttachment.CFrame = anchorPart.CFrame:ToObjectSpace(worldCF)
	driveAttachment.Parent = anchorPart

	local hinge = Instance.new("HingeConstraint")
	hinge.Name = hingeName
	hinge.Attachment0 = pivotAttachment
	hinge.Attachment1 = driveAttachment
	hinge.ActuatorType = Enum.ActuatorType.Servo
	hinge.AngularSpeed = 5
	hinge.ServoMaxTorque = 15000
	hinge.TargetAngle = 0
	hinge.LimitsEnabled = false
	hinge.Parent = movingPart

	return hinge
end

--====================================================================
-- STEP 1 — DOORS (anchor → break → weld/constrain → unanchor)
--====================================================================

local DOOR_TAGS = {
	"VOE_DoorFL_Root","VOE_DoorFR_Root","VOE_DoorRL_Root","VOE_DoorRR_Root"
}

-- Build door set
local doorRoots = {}
local doorSet = {}
for _, tag in ipairs(DOOR_TAGS) do
	for _, root in ipairs(getTagged(tag)) do
		table.insert(doorRoots, root)
		doorSet[root] = true
		local prefix = string.match(tag, "VOE_(Door%a%a)_Root")
		if prefix then
			local partTag = "VOE_" .. prefix .. "_Part"
			for _, p in ipairs(getTagged(partTag)) do
				doorSet[p] = true
			end
		end
	end
end

-- ① ANCHOR FIRST — lock doors in place so they don't shift
for part in pairs(doorSet) do
	if part:IsA("BasePart") then
		part.Anchored = true
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
	end
end

-- ② BREAK WELDS — remove external cross-welds, then clean internals
breakExternalWelds(doorSet)

for part in pairs(doorSet) do
	breakWelds(part)
end

-- ③ REWELD ROOT ↔ PART
for _, tag in ipairs(DOOR_TAGS) do
	for _, root in ipairs(getTagged(tag)) do
		local prefix = string.match(tag, "VOE_(Door%a%a)_Root")
		if prefix then
			local partTag = "VOE_" .. prefix .. "_Part"
			for _, p in ipairs(getTagged(partTag)) do
				if p ~= root then
					weld(root, p)
				end
			end
		end
	end
end

-- ④ CREATE ATTACHMENTS AND HINGE CONSTRAINTS
local function createHinge(part, pivot)
	local worldCF = pivot.WorldCFrame

	-- Use the existing VOE_HingePivot attachment directly (it's already on the door root)
	local a1 = Instance.new("Attachment")
	a1.CFrame = driveSeat.CFrame:ToObjectSpace(worldCF)
	-- Name the drive-side attachment so it isn't left as an anonymous "Attachment" instance
	local roleName = nil
	for _, tag in ipairs(CollectionService:GetTags(part)) do
		local r = string.match(tag, "^VOE_(%a+)_Root$")
		if r then
			roleName = r
			break
		end
	end
	a1.Name = roleName and ("VOE_HingeDrive_" .. roleName) or "VOE_HingeDrive"
	a1.Parent = driveSeat

	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0 = pivot
	hinge.Attachment1 = a1
	hinge.ActuatorType = Enum.ActuatorType.Servo
	hinge.AngularSpeed = 3
	hinge.ServoMaxTorque = 15000
	hinge.TargetAngle = 0
	hinge.Parent = part

	-- Name the hinge so handler modules can find it (VOE_Hinge_VOE_<Role>)
	for _, tag in ipairs(CollectionService:GetTags(part)) do
		local role = string.match(tag, "^VOE_(%a+)_Root$")
		if role then
			hinge.Name = "VOE_Hinge_VOE_" .. role
			break
		end
	end
	if not hinge.Name:find("^VOE_Hinge") then
		hinge.Name = "VOE_Hinge_" .. part.Name
	end

	return hinge
end

-- If users placed attachments but left them with the default name "Attachment",
-- attempt to rename them to the expected VOE pivot name so the hinge creation below can detect them.
for _, root in ipairs(doorRoots) do
	for _, child in ipairs(root:GetDescendants()) do
		if child:IsA("Attachment") and child.Name == "Attachment" then
			child.Name = "VOE_HingePivot"
		end
	end
end

for _, root in ipairs(doorRoots) do
	for _, child in ipairs(root:GetDescendants()) do
		if child:IsA("Attachment") and child.Name:find("Hinge") then
			createHinge(root, child)
		end
	end
end

-- Allow constraint graph to register
task.wait()

-- ⑤ UNANCHOR LAST — release only after everything is connected
for part in pairs(doorSet) do
	if part:IsA("BasePart") then
		part.Anchored = false
	end
end

--====================================================================
-- STEP 2 — WINDOWS (STABLE PIPELINE: anchor → break → weld/constrain → unanchor)
--====================================================================

local windowRoots = getWindowRoots()
local windowSet = buildWindowSet(windowRoots)

-- ① ANCHOR FIRST — lock windows in place so they can't fall
for part in pairs(windowSet) do
	if part:IsA("BasePart") then
		part.Anchored = true
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
	end
end

-- ② BREAK WELDS — remove external cross-welds, then clean internals
breakExternalWelds(windowSet)

for part in pairs(windowSet) do
	breakWelds(part)
end

-- ③ ADD NEW WELDS, ATTACHMENTS, AND CONSTRAINTS

-- Reweld root ↔ part (tag-based, not name-based)
for _, tag in ipairs(WINDOW_TAGS) do
	for _, root in ipairs(getTagged(tag)) do
		local prefix = string.match(tag, "VOE_(Window%a%a)_Root")
		if prefix then
			local partTag = "VOE_" .. prefix .. "_Part"

			for _, p in ipairs(getTagged(partTag)) do
				if p ~= root then
					weld(root, p)
				end
			end
		end
	end
end

-- Create PrismaticConstraints for sliding windows
local function createPrismatic(windowRoot, slideFrame)
	local worldCF = slideFrame.WorldCFrame

	local a0 = Instance.new("Attachment")
	a0.CFrame = windowRoot.CFrame:ToObjectSpace(worldCF)
	-- Name the anchor attachment so it's identifiable and not left as anonymous
	a0.Name = "VOE_WindowAnchor_" .. (windowRoot.Name or "Root")
	a0.Parent = windowRoot

	local prismatic = Instance.new("PrismaticConstraint")
	prismatic.Attachment0 = a0
	prismatic.Attachment1 = slideFrame
	prismatic.ActuatorType = Enum.ActuatorType.Servo
	prismatic.ServoMaxForce = 5000
	prismatic.Speed = 5
	prismatic.LowerLimit = 0
	prismatic.UpperLimit = 1.8
	prismatic.TargetPosition = 0
	prismatic.Name = "WindowSlideConstraint"
	prismatic.Parent = windowRoot

	return prismatic
end

-- If users placed slide-frame attachments but left them with the default name "Attachment",
-- rename them to the expected VOE_SlideFrame so prismatic creation below can find them.
for _, tag in ipairs(WINDOW_TAGS) do
	local prefix = string.match(tag, "VOE_(Window%a%a)_Root")
	if prefix then
		local partTag = "VOE_" .. prefix .. "_Part"
		for _, p in ipairs(getTagged(partTag)) do
			for _, child in ipairs(p:GetDescendants()) do
				if child:IsA("Attachment") and child.Name == "Attachment" then
					child.Name = "VOE_SlideFrame"
				end
			end
		end
	end
end

for _, inst in ipairs(vehicleModel:GetDescendants()) do
	if inst:IsA("Attachment") and inst.Name == "VOE_SlideFrame" then
		local slidePart = inst.Parent
		if not slidePart or not slidePart:IsA("BasePart") then continue end

		local parentFolder = slidePart.Parent
		local matchedRoot = nil

		if parentFolder then
			for _, root in ipairs(windowRoots) do
				if root.Parent == parentFolder then
					matchedRoot = root
					break
				end
			end
		end

		if not matchedRoot then
			local minDist = math.huge
			local slideWorldPos = inst.WorldCFrame.Position
			for _, root in ipairs(windowRoots) do
				local dist = (root.Position - slideWorldPos).Magnitude
				if dist < minDist then
					minDist = dist
					matchedRoot = root
				end
			end
		end

		if matchedRoot then
			createPrismatic(matchedRoot, inst)
		end
	end
end

-- Allow constraint graph to register
task.wait()

-- ④ UNANCHOR LAST — release only after everything is connected
-- Unanchor ALL parts in the window set (roots + descendants + Part-tagged siblings)
for part in pairs(windowSet) do
	if part:IsA("BasePart") then
		part.Anchored = false
	end
end

--====================================================================
-- STEP 3 — HOOD & TRUNK (anchor → break → weld/constrain → unanchor)
--====================================================================

local HINGED_PAIRS = {
	{RootTag = "VOE_Hood_Root", PartTag = "VOE_Hood_Part"},
	{RootTag = "VOE_Trunk_Root", PartTag = "VOE_Trunk_Part"},
	{RootTag = "VOE_WiperLeft_Root", PartTag = "VOE_WiperLeft_Part"},
	{RootTag = "VOE_WiperRight_Root", PartTag = "VOE_WiperRight_Part"},
}

for _, pair in ipairs(HINGED_PAIRS) do
	local roots = getTagged(pair.RootTag)
	local parts = getTagged(pair.PartTag)

	-- Build part set for this group
	local partSet = {}
	for _, root in ipairs(roots) do
		partSet[root] = true
	end
	for _, p in ipairs(parts) do
		partSet[p] = true
	end

	-- ① ANCHOR FIRST
	for part in pairs(partSet) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end

	-- ② BREAK WELDS
	breakExternalWelds(partSet)
	for part in pairs(partSet) do
		breakWelds(part)
	end

	-- ③ REWELD ROOT ↔ PART
	for _, root in ipairs(roots) do
		for _, p in ipairs(parts) do
			if p ~= root then
				weld(root, p)
			end
		end

		-- Create hinge if a VOE_HingePivot attachment exists on the root
		for _, child in ipairs(root:GetDescendants()) do
			if child:IsA("Attachment") and child.Name:find("Hinge") then
				createHinge(root, child)
			end
		end
	end

	-- Allow constraint graph to register
	task.wait()

	-- ④ UNANCHOR LAST
	for part in pairs(partSet) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end
end

--====================================================================
-- STEP 4 — SPOTLIGHTS (anchor → break → constrain → unanchor)
--====================================================================

local SPOTLIGHT_SPECS = {
	{
		Id = "Left",
		LightTag = "VOE_SpotlightLeft_Lamp",
		BaseRootTag = "VOE_SpotlightLeft_BaseRoot",
		BasePartTag = "VOE_SpotlightLeft_BasePart",
		ArmRootTag = "VOE_SpotlightLeft_ArmRoot",
		ArmPartTag = "VOE_SpotlightLeft_ArmPart",
		LampAttachment = "SpotlightLeft_Lamp",
	},
	{
		Id = "Right",
		LightTag = "VOE_SpotlightRight_Lamp",
		BaseRootTag = "VOE_SpotlightRight_BaseRoot",
		BasePartTag = "VOE_SpotlightRight_BasePart",
		ArmRootTag = "VOE_SpotlightRight_ArmRoot",
		ArmPartTag = "VOE_SpotlightRight_ArmPart",
		LampAttachment = "SpotlightRight_Lamp",
	},
}

local spotlightTaggedSet = buildTaggedPartSet("VOE_Spotlight")
if next(spotlightTaggedSet) then
	breakExternalWelds(spotlightTaggedSet)
	breakWeldsTouching(spotlightTaggedSet)
	for part in pairs(spotlightTaggedSet) do
		if part:IsA("BasePart") then
			breakWelds(part)
		end
	end
end

for _, spec in ipairs(SPOTLIGHT_SPECS) do
	local baseRoot = getFirstTaggedPart(spec.BaseRootTag)
	local baseParts = getTagged(spec.BasePartTag)
	local armRoot = getFirstTaggedPart(spec.ArmRootTag)
	local armParts = getTagged(spec.ArmPartTag)
	local lampAttachment = findAttachmentByName(spec.LampAttachment)
	local lampPart = lampAttachment and lampAttachment.Parent

	if lampPart and not lampPart:IsA("BasePart") then
		lampPart = nil
	end

	for _, lightPart in ipairs(getTagged(spec.LightTag)) do
		addPartAndDescendants(spotlightTaggedSet, lightPart)
		if not lampPart and lightPart:IsA("BasePart") then
			lampPart = lightPart
		end
	end

	local spotlightSet = {}
	addPartAndDescendants(spotlightSet, baseRoot)
	for _, part in ipairs(baseParts) do
		addPartAndDescendants(spotlightSet, part)
	end
	addPartAndDescendants(spotlightSet, armRoot)
	for _, part in ipairs(armParts) do
		addPartAndDescendants(spotlightSet, part)
	end
	addPartAndDescendants(spotlightSet, lampPart)

	if next(spotlightSet) then
		for part in pairs(spotlightSet) do
			part.Anchored = true
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end

		breakWeldsTouching(spotlightSet)
		for part in pairs(spotlightSet) do
			breakWelds(part)
		end

		if baseRoot then
			for _, part in ipairs(baseParts) do
				if part and part:IsA("BasePart") and part ~= baseRoot then
					weld(baseRoot, part)
				end
			end
		end
		if armRoot then
			for _, part in ipairs(armParts) do
				if part and part:IsA("BasePart") and part ~= armRoot then
					weld(armRoot, part)
				end
			end
		end

		if baseRoot and armRoot then
			local basePivot = findAttachmentInRoot(baseRoot, "VOE_HingePivot")
			if basePivot then
				createServoHinge(
					baseRoot,
					basePivot,
					armRoot,
					"VOE_Spotlight_" .. spec.Id .. "_BaseHinge",
					"VOE_Spotlight_" .. spec.Id .. "_BaseDrive"
				)
			end
		end

		if armRoot then
			local armPivot = findAttachmentInRoot(armRoot, "VOE_HingePivot")
			if armPivot then
				createServoHinge(
					armRoot,
					armPivot,
					driveSeat,
					"VOE_Spotlight_" .. spec.Id .. "_ArmHinge",
					"VOE_Spotlight_" .. spec.Id .. "_ArmDrive"
				)
			end
		end

		if lampPart and lampAttachment then
			createServoHinge(
				lampPart,
				lampAttachment,
				armPart or armRoot or basePart or baseRoot,
				"VOE_Spotlight_" .. spec.Id .. "_LampHinge",
				"VOE_Spotlight_" .. spec.Id .. "_LampDrive"
			)
		end

		task.wait()

		for part in pairs(spotlightSet) do
			part.Anchored = false
		end
	end
end

--====================================================================
-- STEP 5 — EXHAUST (anchor → break → unanchor)
--====================================================================

local exhaustTaggedSet = {}
for _, tag in ipairs({"VOE_Exhaust_Root", "VOE_Exhaust_Part"}) do
	for part in pairs(buildTaggedPartSet(tag)) do
		exhaustTaggedSet[part] = true
	end
end

if next(exhaustTaggedSet) then
	for part in pairs(exhaustTaggedSet) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end

	breakExternalWelds(exhaustTaggedSet)
	breakWeldsTouching(exhaustTaggedSet)
	for part in pairs(exhaustTaggedSet) do
		if part:IsA("BasePart") then
			breakWelds(part)
		end
	end

	-- ③ REWELD ROOT ↔ PART
	local exhaustRoots = getTagged("VOE_Exhaust_Root")
	local exhaustParts = getTagged("VOE_Exhaust_Part")
	for _, part in ipairs(exhaustParts) do
		if part and part:IsA("BasePart") then
			local closestRoot, minDist = nil, math.huge
			for _, root in ipairs(exhaustRoots) do
				if root and root:IsA("BasePart") and root ~= part then
					local dist = (part.Position - root.Position).Magnitude
					if dist < minDist then
						minDist = dist
						closestRoot = root
					end
				end
			end
			if closestRoot then
				weld(closestRoot, part)
			end
		end
	end

	-- ④ CREATE MOTOR6D BETWEEN EXHAUST ROOT AND DRIVE SEAT
	local seatAttachmentName = "VOE_ExhaustMotorPivot"
	local seatAttachment = driveSeat:FindFirstChild(seatAttachmentName)
	if not seatAttachment then
		seatAttachment = Instance.new("Attachment")
		seatAttachment.Name = seatAttachmentName
		seatAttachment.Parent = driveSeat
	end

	for index, root in ipairs(exhaustRoots) do
		if root and root:IsA("BasePart") then
			local rootPivot = findAttachmentInRoot(root, "VOE_MotorPivot")
			if not rootPivot then
				rootPivot = Instance.new("Attachment")
				rootPivot.Name = "VOE_MotorPivot"
				rootPivot.WorldCFrame = root.CFrame
				rootPivot.Parent = root
			end

			seatAttachment.WorldCFrame = rootPivot.WorldCFrame
			local motorName = "VOE_ExhaustMotor_Exhaust" .. tostring(index)
			local motor = root:FindFirstChild(motorName)
			if not motor or not motor:IsA("Motor6D") then
				motor = Instance.new("Motor6D")
				motor.Name = motorName
				motor.Part0 = driveSeat
				motor.Part1 = root
				motor.C0 = driveSeat.CFrame:ToObjectSpace(seatAttachment.WorldCFrame)
				motor.C1 = root.CFrame:ToObjectSpace(rootPivot.WorldCFrame)
				motor.Parent = root
			end
		end
	end

	for part in pairs(exhaustTaggedSet) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end
end

--====================================================================
-- STEP 6 — INITIALIZE HANDLER MODULES
--====================================================================

local function safeRequire(moduleScript)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then return nil end
	local ok, result = pcall(require, moduleScript)
	if not ok then
		warn("[VOE_RigBootstrap] Failed to require " .. moduleScript.Name .. ": " .. tostring(result))
		return nil
	end
	return result
end

-- Initialize ClickHandler (creates ClickDetectors on tagged parts)
local clickHandler = safeRequire(script:FindFirstChild("ClickHandler"))
if clickHandler and clickHandler.Initialize then
	clickHandler.Initialize(vehicleModel, voeState)
	print("[VOE_RigBootstrap] ClickHandler initialized")
end

-- Initialize DoorsHandler (server-side door state management)
local doorsHandler = safeRequire(script:FindFirstChild("DoorsHandler"))
if doorsHandler and doorsHandler.Initialize then
	doorsHandler.Initialize(vehicleModel, voeState)
	print("[VOE_RigBootstrap] DoorsHandler initialized")
end

-- Initialize HoodHandler
local hoodHandler = safeRequire(script:FindFirstChild("HoodHandler"))
if hoodHandler and hoodHandler.Initialize then
	hoodHandler.Initialize(vehicleModel, voeState)
	print("[VOE_RigBootstrap] HoodHandler initialized")
end

-- Initialize TrunkHandler
local trunkHandler = safeRequire(script:FindFirstChild("TrunkHandler"))
if trunkHandler and trunkHandler.Initialize then
	trunkHandler.Initialize(vehicleModel, voeState)
	print("[VOE_RigBootstrap] TrunkHandler initialized")
end

-- Initialize PuddleLightsHandler
local puddleLightsHandler = safeRequire(script:FindFirstChild("PuddleLightsHandler"))
if puddleLightsHandler and puddleLightsHandler.Initialize then
	puddleLightsHandler.Initialize(vehicleModel, voeState)
	print("[VOE_RigBootstrap] PuddleLightsHandler initialized")
end

-- Initialize DomelightHandler
local domelightHandler = safeRequire(script:FindFirstChild("DomelightHandler"))
if domelightHandler and domelightHandler.Initialize then
	domelightHandler.Initialize(vehicleModel, voeState)
	print("[VOE_RigBootstrap] DomelightHandler initialized")
end

-- Initialize SpotlightsHandler
local spotlightsHandler = safeRequire(script:FindFirstChild("SpotlightsHandler"))
if spotlightsHandler and spotlightsHandler.Initialize then
	spotlightsHandler.Initialize(vehicleModel, voeState)
	print("[VOE_RigBootstrap] SpotlightsHandler initialized")
end

--====================================================================
-- DONE
--====================================================================

vehicleModel:SetAttribute("VOE_RigReady", true)

print("[VOE_RigBootstrap] Rig setup complete — doors, windows, spotlights, click detection, handlers all initialized")
