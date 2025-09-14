-- ClosestCam_Movable.lua
-- LocalScript 用（StarterPlayerScripts に置いても、loadstring 経由で呼んでも動きます）

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- 設定
local SMOOTHNESS = 8        -- 数値を大きくすると追従が滑らかになります（目安: 4〜12）
local BUTTON_SIZE = UDim2.new(0, 110, 0, 40)
local BUTTON_POS  = UDim2.new(1, -120, 1, -60) -- 初期位置

-- 内部状態
local enabled = false

-- 一番近いプレイヤー検索
local function getClosestPlayer()
	if not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil end
	local myPos = localPlayer.Character.HumanoidRootPart.Position

	local closestPlayer = nil
	local closestDistance = math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= localPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
			local distance = (p.Character.HumanoidRootPart.Position - myPos).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestPlayer = p
			end
		end
	end
	return closestPlayer
end

-- UI（スマホ対応・ドラッグ可能ボタン）を作る
local function createToggleButton()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("ClosestCamGui")
	if existing then
		return existing.ToggleButton
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ClosestCamGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local btn = Instance.new("TextButton")
	btn.Name = "ToggleButton"
	btn.Size = BUTTON_SIZE
	btn.Position = BUTTON_POS
	btn.AnchorPoint = Vector2.new(0, 0)
	btn.Text = "Lock: OFF"
	btn.TextScaled = true
	btn.Parent = screenGui
	btn.AutoButtonColor = true
	btn.BackgroundTransparency = 0.25
	btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.BorderSizePixel = 0
	btn.ZIndex = 10

	-- ドラッグ用変数
	local dragging = false
	local dragInput
	local dragStart
	local startPos

	-- ドラッグ開始
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = btn.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	-- ドラッグ移動検知
	btn.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	-- RenderStepped でボタン移動
	RunService.RenderStepped:Connect(function()
		if dragging and dragInput then
			local delta = dragInput.Position - dragStart
			btn.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)

	return btn
end

local toggleButton = createToggleButton()

-- ON/OFF 切替
local function setEnabled(on)
	enabled = on
	toggleButton.Text = enabled and "Lock: ON" or "Lock: OFF"
end

-- ボタン押下（クリック・タッチ対応）
toggleButton.MouseButton1Click:Connect(function()
	setEnabled(not enabled)
end)
toggleButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		setEnabled(not enabled)
	end
end)

-- 毎フレームで追従（合同モード：位置は保持、向きだけ追従）
RunService.RenderStepped:Connect(function(dt)
	if not enabled then return end
	if not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

	local closest = getClosestPlayer()
	if closest and closest.Character and closest.Character:FindFirstChild("HumanoidRootPart") then
		local targetPos = closest.Character.HumanoidRootPart.Position
		local currentPos = camera.CFrame.Position
		local desiredLook = CFrame.new(currentPos, targetPos)

		-- CameraType は Custom のまま、向きだけ補間
		camera.CFrame = CFrame.new(camera.CFrame.Position) * camera.CFrame.Rotation:Lerp(desiredLook.Rotation, math.clamp(dt * SMOOTHNESS, 0, 1))
	end
end)
