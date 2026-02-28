--[[
	HUDClient — cartoon-style HUD elements.
	- Health bar (chunky, colour shifts red when low)
	- Ammo counter (large, flashes when empty)
	- Minimap placeholder (static circle)
	- Extraction zone direction arrow
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local HUDClient = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local hudGui = nil
local healthFill = nil
local healthLabel = nil
local ammoLabel = nil
local arrowFrame = nil
local ammoFlashing = false

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return Color3.new(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t
	)
end

local function createHUD()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 2
	gui.Parent = playerGui

	-- ===== HEALTH BAR (bottom left) =====
	local healthContainer = Instance.new("Frame")
	healthContainer.Name = "HealthContainer"
	healthContainer.Size = UDim2.new(0, Config.HUD.HealthBarWidth, 0, Config.HUD.HealthBarHeight)
	healthContainer.Position = UDim2.new(0, 24, 1, -60)
	healthContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	healthContainer.BackgroundTransparency = 0.2
	healthContainer.Parent = gui

	local healthCorner = Instance.new("UICorner")
	healthCorner.CornerRadius = UDim.new(0, 10)
	healthCorner.Parent = healthContainer

	local healthStroke = Instance.new("UIStroke")
	healthStroke.Color = Color3.fromRGB(60, 60, 60)
	healthStroke.Thickness = 3
	healthStroke.Parent = healthContainer

	-- Fill bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, -8, 1, -8)
	fill.Position = UDim2.new(0, 4, 0, 4)
	fill.BackgroundColor3 = Config.HUD.HealthHighColor
	fill.Parent = healthContainer

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 7)
	fillCorner.Parent = fill

	healthFill = fill

	-- Health text overlay
	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.Size = UDim2.new(1, 0, 1, 0)
	hpText.BackgroundTransparency = 1
	hpText.Text = "100"
	hpText.Font = Enum.Font.FredokaOne
	hpText.TextSize = 20
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.TextStrokeTransparency = 0.3
	hpText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	hpText.ZIndex = 2
	hpText.Parent = healthContainer

	healthLabel = hpText

	-- ===== AMMO COUNTER (bottom right) =====
	local ammoContainer = Instance.new("Frame")
	ammoContainer.Name = "AmmoContainer"
	ammoContainer.Size = UDim2.new(0, 140, 0, 50)
	ammoContainer.Position = UDim2.new(1, -164, 1, -70)
	ammoContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	ammoContainer.BackgroundTransparency = 0.2
	ammoContainer.Parent = gui

	local ammoCorner = Instance.new("UICorner")
	ammoCorner.CornerRadius = UDim.new(0, 10)
	ammoCorner.Parent = ammoContainer

	local ammoStroke = Instance.new("UIStroke")
	ammoStroke.Color = Color3.fromRGB(60, 60, 60)
	ammoStroke.Thickness = 3
	ammoStroke.Parent = ammoContainer

	local ammoText = Instance.new("TextLabel")
	ammoText.Name = "AmmoText"
	ammoText.Size = UDim2.new(1, 0, 1, 0)
	ammoText.BackgroundTransparency = 1
	ammoText.Text = "30 / 30"
	ammoText.Font = Enum.Font.FredokaOne
	ammoText.TextSize = 28
	ammoText.TextColor3 = Color3.new(1, 1, 1)
	ammoText.TextStrokeTransparency = 0.3
	ammoText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	ammoText.Parent = ammoContainer

	ammoLabel = ammoText

	-- ===== MINIMAP PLACEHOLDER (top right) =====
	local minimapSize = Config.HUD.MinimapSize

	local minimap = Instance.new("Frame")
	minimap.Name = "Minimap"
	minimap.Size = UDim2.new(0, minimapSize, 0, minimapSize)
	minimap.Position = UDim2.new(1, -minimapSize - 16, 0, 16)
	minimap.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	minimap.BackgroundTransparency = 0.2
	minimap.Parent = gui

	local minimapCorner = Instance.new("UICorner")
	minimapCorner.CornerRadius = UDim.new(0.5, 0)
	minimapCorner.Parent = minimap

	local minimapStroke = Instance.new("UIStroke")
	minimapStroke.Color = Color3.fromRGB(80, 80, 100)
	minimapStroke.Thickness = 3
	minimapStroke.Parent = minimap

	-- "MINIMAP" placeholder text
	local minimapText = Instance.new("TextLabel")
	minimapText.Size = UDim2.new(1, 0, 1, 0)
	minimapText.BackgroundTransparency = 1
	minimapText.Text = "MAP"
	minimapText.Font = Enum.Font.GothamBold
	minimapText.TextSize = 14
	minimapText.TextColor3 = Color3.fromRGB(80, 80, 100)
	minimapText.Parent = minimap

	-- Player dot in center
	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 8, 0, 8)
	dot.Position = UDim2.new(0.5, -4, 0.5, -4)
	dot.BackgroundColor3 = Color3.fromRGB(80, 200, 255)
	dot.Parent = minimap

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(0.5, 0)
	dotCorner.Parent = dot

	-- ===== EXTRACTION ARROW (screen edge indicator) =====
	local arrow = Instance.new("Frame")
	arrow.Name = "ExtractionArrow"
	arrow.Size = UDim2.new(0, 40, 0, 40)
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.new(0.5, 0, 0.1, 0)
	arrow.BackgroundTransparency = 1
	arrow.Visible = false
	arrow.Parent = gui

	local arrowIcon = Instance.new("TextLabel")
	arrowIcon.Name = "Icon"
	arrowIcon.Size = UDim2.new(1, 0, 1, 0)
	arrowIcon.BackgroundTransparency = 1
	arrowIcon.Text = "^"
	arrowIcon.Font = Enum.Font.FredokaOne
	arrowIcon.TextSize = 36
	arrowIcon.TextColor3 = Config.Extraction.ZoneColor
	arrowIcon.TextStrokeTransparency = 0
	arrowIcon.TextStrokeColor3 = Color3.fromRGB(0, 40, 20)
	arrowIcon.Parent = arrow

	-- Small label below arrow
	local arrowLabel = Instance.new("TextLabel")
	arrowLabel.Size = UDim2.new(0, 80, 0, 16)
	arrowLabel.Position = UDim2.new(0.5, -40, 1, 2)
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.Text = "EXTRACT"
	arrowLabel.Font = Enum.Font.GothamBold
	arrowLabel.TextSize = 10
	arrowLabel.TextColor3 = Config.Extraction.ZoneColor
	arrowLabel.TextStrokeTransparency = 0.3
	arrowLabel.Parent = arrow

	arrowFrame = arrow

	hudGui = gui
end

local function updateHealthBar()
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)

	-- Update fill width
	healthFill.Size = UDim2.new(ratio, -8 * (1 - ratio), 1, -8)

	-- Colour shift
	local colour
	if ratio <= Config.HUD.HealthLowThreshold then
		colour = Config.HUD.HealthLowColor
	elseif ratio <= Config.HUD.HealthMidThreshold then
		local t = (ratio - Config.HUD.HealthLowThreshold) / (Config.HUD.HealthMidThreshold - Config.HUD.HealthLowThreshold)
		colour = lerpColor(Config.HUD.HealthLowColor, Config.HUD.HealthMidColor, t)
	else
		local t = (ratio - Config.HUD.HealthMidThreshold) / (1 - Config.HUD.HealthMidThreshold)
		colour = lerpColor(Config.HUD.HealthMidColor, Config.HUD.HealthHighColor, t)
	end

	healthFill.BackgroundColor3 = colour
	healthLabel.Text = tostring(math.ceil(humanoid.Health))
end

local function updateAmmo(weaponClient)
	local current = weaponClient.ammo
	local max = weaponClient.maxAmmo

	if weaponClient.reloading then
		ammoLabel.Text = "RELOADING"
		ammoLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
		return
	end

	ammoLabel.Text = tostring(current) .. " / " .. tostring(max)

	if current <= 0 then
		-- Flash red when empty
		if not ammoFlashing then
			ammoFlashing = true
			task.spawn(function()
				while ammoFlashing and current <= 0 do
					ammoLabel.TextColor3 = Config.HUD.AmmoFlashColor
					task.wait(0.15)
					ammoLabel.TextColor3 = Color3.new(1, 1, 1)
					task.wait(0.15)
					-- Re-check
					current = weaponClient.ammo
				end
				ammoFlashing = false
				ammoLabel.TextColor3 = Color3.new(1, 1, 1)
			end)
		end
	else
		ammoFlashing = false
		ammoLabel.TextColor3 = Color3.new(1, 1, 1)
	end
end

local function updateExtractionArrow()
	local character = player.Character
	if not character then
		arrowFrame.Visible = false
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		arrowFrame.Visible = false
		return
	end

	local camera = workspace.CurrentCamera
	local zonePos = Config.Extraction.ZonePosition

	-- Check if zone is on screen
	local screenPos, onScreen = camera:WorldToScreenPoint(zonePos)
	if onScreen then
		arrowFrame.Visible = false
		return
	end

	arrowFrame.Visible = true

	-- Calculate direction to zone in screen space
	local viewportSize = camera.ViewportSize
	local centerX = viewportSize.X / 2
	local centerY = viewportSize.Y / 2

	local dirX = screenPos.X - centerX
	local dirY = screenPos.Y - centerY

	-- Normalize and position on screen edge
	local angle = math.atan2(dirY, dirX)
	local edgeMargin = 50

	-- Clamp to screen bounds
	local maxX = viewportSize.X / 2 - edgeMargin
	local maxY = viewportSize.Y / 2 - edgeMargin

	local scale = math.min(
		math.abs(dirX) > 0.01 and math.abs(maxX / dirX) or 999,
		math.abs(dirY) > 0.01 and math.abs(maxY / dirY) or 999,
		1
	)

	local posX = 0.5 + (dirX * scale) / viewportSize.X
	local posY = 0.5 + (dirY * scale) / viewportSize.Y

	posX = math.clamp(posX, edgeMargin / viewportSize.X, 1 - edgeMargin / viewportSize.X)
	posY = math.clamp(posY, edgeMargin / viewportSize.Y, 1 - edgeMargin / viewportSize.Y)

	arrowFrame.Position = UDim2.new(posX, 0, posY, 0)
	arrowFrame.Rotation = math.deg(angle) - 90
end

function HUDClient.init(weaponClient)
	createHUD()

	RunService.Heartbeat:Connect(function()
		updateHealthBar()
		updateAmmo(weaponClient)
		updateExtractionArrow()
	end)
end

return HUDClient
