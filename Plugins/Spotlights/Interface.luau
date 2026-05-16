local Interface = {}

function Interface.create(parentGui, context)
	-- context: { StateValues, RotationStates, rotateBase, rotateArm, ROLE_ORDER, debugLog }
	local StateValues = context.StateValues
	local RotationStates = context.RotationStates
	local rotateBase = context.rotateBase
	local rotateArm = context.rotateArm
	local ROLE_ORDER = context.ROLE_ORDER
	local debugLog = context.debugLog

	if not parentGui or not parentGui:IsA("ScreenGui") then
		warn("[Spotlights] Could not find A-Chassis Interface ScreenGui")
		return
	end

	-- Destroy existing panel if present
	local existing = parentGui:FindFirstChild("VOE_SpotlightPanel")
	if existing then existing:Destroy() end

	-- Layout constants
	local COL_W = 100
	local COL_PAD = 8
	local BTN_W = 90
	local BTN_H = 26
	local BTN_PAD = 3
	local HEADER_H = 18
	local PANEL_PAD = 6
	local NUM_BTNS = 5

	local PANEL_W = COL_PAD + COL_W * 2 + COL_PAD
	local PANEL_H = PANEL_PAD + HEADER_H + BTN_PAD + (BTN_H + BTN_PAD) * NUM_BTNS + PANEL_PAD

	-- Column definitions: id, title
	local columns = {
		{ id = "Left",  title = "LEFT SPOT" },
		{ id = "Right", title = "RIGHT SPOT" },
	}

	-- Button definitions per column: { name, label }
	local buttonDefs = {
		{ "Toggle",    "OFF" },
		{ "BaseLeft",  "← BASE" },
		{ "BaseRight", "BASE →" },
		{ "ArmUp",     "ARM ↑" },
		{ "ArmDown",   "ARM ↓" },
	}

	-- Main panel frame
	local panel = Instance.new("Frame")
	panel.Name = "VOE_SpotlightPanel"
	panel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
	panel.Position = UDim2.new(0, 8, 0.5, -PANEL_H / 2)
	panel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	panel.Parent = parentGui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 6)
	panelCorner.Parent = panel

	-- Panel title
	local panelTitle = Instance.new("TextLabel")
	panelTitle.Name = "PanelTitle"
	panelTitle.Size = UDim2.new(1, 0, 0, HEADER_H)
	panelTitle.Position = UDim2.new(0, 0, 0, PANEL_PAD)
	panelTitle.BackgroundTransparency = 1
	panelTitle.Text = "SPOTLIGHTS"
	panelTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
	panelTitle.TextSize = 11
	panelTitle.Font = Enum.Font.GothamBold
	panelTitle.Parent = panel

	-- Build each column
	for colIdx, col in ipairs(columns) do
		local id = col.id
		local colX = COL_PAD + (colIdx - 1) * (COL_W + COL_PAD)

		-- Column header
		local header = Instance.new("TextLabel")
		header.Name = "Header_" .. id
		header.Size = UDim2.new(0, COL_W, 0, HEADER_H)
		header.Position = UDim2.new(0, colX, 0, PANEL_PAD + HEADER_H + BTN_PAD)
		header.BackgroundTransparency = 1
		header.Text = col.title
		header.TextColor3 = Color3.fromRGB(150, 150, 150)
		header.TextSize = 9
		header.Font = Enum.Font.GothamBold
		header.Parent = panel

		-- Column buttons
		for btnIdx, def in ipairs(buttonDefs) do
			local btnName, btnLabel = def[1], def[2]
			local btnY = PANEL_PAD + HEADER_H + BTN_PAD + HEADER_H + BTN_PAD + (btnIdx - 1) * (BTN_H + BTN_PAD)

			local btn = Instance.new("TextButton")
			btn.Name = id .. "_" .. btnName
			btn.Size = UDim2.new(0, BTN_W, 0, BTN_H)
			btn.Position = UDim2.new(0, colX + (COL_W - BTN_W) / 2, 0, btnY)
			btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
			btn.TextColor3 = Color3.fromRGB(170, 170, 170)
			btn.TextSize = 9
			btn.Font = Enum.Font.GothamBold
			btn.BorderSizePixel = 0
			btn.Text = btnLabel
			btn.AutoButtonColor = true
			btn.Parent = panel

			local btnCorner = Instance.new("UICorner")
			btnCorner.CornerRadius = UDim.new(0, 4)
			btnCorner.Parent = btn

			-- Wire up button actions
			if btnName == "Toggle" then
				-- Single-click toggle with live visual feedback
				local stateVal = StateValues["Spotlight" .. id]
				if stateVal then
					local function updateToggle()
						local isOn = stateVal.Value
						btn.Text = isOn and "ON" or "OFF"
						btn.BackgroundColor3 = isOn
							and Color3.fromRGB(0, 100, 0)
							or Color3.fromRGB(35, 35, 35)
						btn.TextColor3 = isOn
							and Color3.fromRGB(100, 255, 100)
							or Color3.fromRGB(170, 170, 170)
					end
					updateToggle()
					stateVal.Changed:Connect(updateToggle)
				end
				btn.MouseButton1Click:Connect(function()
					if StateValues["Spotlight" .. id] then
						StateValues["Spotlight" .. id].Value = not StateValues["Spotlight" .. id].Value
					end
				end)

			else
				-- Directional buttons: hold to continuously move, release to stop
				local holdConnection = nil
				local HOLD_INTERVAL = 0.08 -- seconds between rotation steps while held

				local function getRotateFunc()
					if btnName == "BaseLeft" then
						return function()
							if RotationStates[id] then
								rotateBase(id, -RotationStates[id].baseMotion.StepAngle)
							end
						end
					elseif btnName == "BaseRight" then
						return function()
							if RotationStates[id] then
								rotateBase(id, RotationStates[id].baseMotion.StepAngle)
							end
						end
					elseif btnName == "ArmUp" then
						return function()
							if RotationStates[id] then
								rotateArm(id, RotationStates[id].armMotion.StepAngle)
							end
						end
					elseif btnName == "ArmDown" then
						return function()
							if RotationStates[id] then
								rotateArm(id, -RotationStates[id].armMotion.StepAngle)
							end
						end
					end
					return nil
				end

				local function startHold()
					if holdConnection then return end
					local rotateFunc = getRotateFunc()
					if not rotateFunc then return end
					rotateFunc() -- immediate first step
					holdConnection = task.spawn(function()
						task.wait(HOLD_INTERVAL)
						while holdConnection do
							rotateFunc()
							task.wait(HOLD_INTERVAL)
						end
					end)
				end

				local function stopHold()
					holdConnection = nil
				end

				btn.MouseButton1Down:Connect(startHold)
				btn.MouseButton1Up:Connect(stopHold)
				btn.MouseLeave:Connect(stopHold)
			end
		end
	end

	-- No cleanup code needed — panel is a child of the A-Chassis Interface
	-- ScreenGui, so it is destroyed automatically when the player exits
	-- the vehicle and the A-Chassis Interface is removed.

	debugLog("GUI", "Spotlight control panel created under A-Chassis Interface")
	return parentGui
end

return Interface