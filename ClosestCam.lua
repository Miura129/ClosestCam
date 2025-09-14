-- ClosestCam.lua
-- LocalScript 用（StarterPlayerScripts に置いても、loadstring 経由で呼んでも動きます）
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- 設定
local SMOOTHNESS = 8        -- 数値を大きくすると追従が滑らかになります（目安: 4〜12）
local BUTTON_SIZE = UDim2.new(0, 110, 0, 40)
local BUTTON_POS  = UDim2.new(1, -120, 1, -60) -- 右下

-- 内部状態
local enabled = false
local previousCameraType = camera.CameraType
local previousCameraCFrame = camera.CFrame

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

-- UI（スマホ対応のボタン）を作る
local function createToggleButton()
	-- 既にある場合は使う（ロードを繰り返しても複数作られないように）
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

	-- 長押しで説明を出す（任意）
	local tooltip = Instance.new("TextLabel")
	tooltip.Size = UDim2.new(0, 220, 0, 36)
	tooltip.Position = UDim2.new(1, -120 - 230, 1, -60)
	tooltip.Text = "最も近いプレイヤーに視点をロックします"
	tooltip.TextScaled = true
	tooltip.BackgroundTransparency = 0.6
	tooltip.Parent = screenGui
	tooltip.Visible = false

	btn.MouseEnter:Connect(function() tooltip.Visible = true end)
	btn.MouseLeave:Connect(function() tooltip.Visible = false end)

	return btn
end

local toggleButton = createToggleButton()

-- ON/OFF 切替処理
local function setEnabled(on)
	enabled = on
	if enabled then
		-- カメラをスクリプト制御にして現在のCFrameを保持
		previousCameraType = camera.CameraType
		previousCameraCFrame = camera.CFrame
		camera.CameraType = Enum.CameraType.Scriptable
		toggleButton.Text = "Lock: ON"
	else
		-- 元に戻す
		camera.CameraType = previousCameraType or Enum.CameraType.Custom
		-- カメラのCFrameを解除時の位置に戻す（元に戻したければ）
		if previousCameraCFrame then
			pcall(function() camera.CFrame = previousCameraCFrame end)
		end
		toggleButton.Text = "Lock: OFF"
	end
end

-- ボタン押下で切り替え（スマホのタップに対応）
toggleButton.MouseButton1Click:Connect(function()
	setEnabled(not enabled)
end)

-- 毎フレームで追従（滑らかに）
RunService.RenderStepped:Connect(function(dt)
	if not enabled then return end
	-- 必要な参照がないときは何もしない
	if not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

	local closest = getClosestPlayer()
	if closest and closest.Character and closest.Character:FindFirstChild("HumanoidRootPart") then
		local myPos = localPlayer.Character.HumanoidRootPart.Position
		local targetPos = closest.Character.HumanoidRootPart.Position

		-- カメラの現在の位置はそのままに、向きをターゲットに向かせる（位置は変更しない）
		local currentPos = camera.CFrame.Position
		local desiredCFrame = CFrame.new(currentPos, targetPos)
		-- 補間して滑らかにする
		local alpha = math.clamp(dt * SMOOTHNESS, 0, 1)
		camera.CFrame = camera.CFrame:Lerp(desiredCFrame, alpha)
	else
		-- 追従対象がいなくなったら特に何もしない（ONのままでも）
	end
end)

-- ゲームから抜ける／キャラがリスポーンしたときの安全処理
localPlayer.CharacterAdded:Connect(function()
	-- キャラ消失→リスポーンのタイミングでカメラ状態がおかしくならないように
	if enabled then
		-- 少し遅らせてカメラを再設定
		wait(0.1)
		previousCameraType = camera.CameraType
		previousCameraCFrame = camera.CFrame
		camera.CameraType = Enum.CameraType.Scriptable
	end
end)

-- 初期は OFF だが、必要なら最初からONにすることも可能
setEnabled(false)
