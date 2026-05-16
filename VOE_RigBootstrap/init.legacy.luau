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
-- STEP 4 — INITIALIZE HANDLER MODULES
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

--====================================================================
-- DONE
--====================================================================

vehicleModel:SetAttribute("VOE_RigReady", true)

print("[VOE_RigBootstrap] Rig setup complete — doors, windows, click detection, handlers all initialized")