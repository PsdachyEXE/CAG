--[[
	ExtractionClient — cartoon-style extraction countdown UI.
	On enter: big countdown timer (5, 4, 3, 2, 1).
	On complete: screen goes white, "EXTRACTED" slams onto screen,
	2 second pause, then results screen appears via RoundEnd remote.
	Countdown interrupted if player leaves zone.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local ExtractionClient = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = nil
local countdownLabel = nil
local progressRing = nil
local whiteFlash = nil
local slamText = nil
local isExtracting = false

local function createExtractionUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ExtractionUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.Enabled = false
	gui.Parent = playerGui

	-- Circular progress ring background
	local ringContainer = Instance.new("Frame")
	ringContainer.Name = "RingContainer"
	ringContainer.Size = UDim2.new(0, 180, 0, 180)
	ringContainer.Position = UDim2.new(0.5, -90, 0.5, -90)
	ringContainer.BackgroundTransparency = 1
	ringContainer.Parent = gui

	-- Outer ring (dark circle)
	local outerRing = Instance.new("Frame")
	outerRing.Name = "OuterRing"
	outerRing.Size = UDim2.new(1, 0, 1, 0)
	outerRing.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	outerRing.BackgroundTransparency = 0.3
	outerRing.Parent = ringContainer

	local outerCorner = Instance.new("UICorner")
	outerCorner.CornerRadius = UDim.new(0.5, 0)
	outerCorner.Parent = outerRing

	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = Config.Extraction.ZoneColor
	ringStroke.Thickness = 4
	ringStroke.Parent = outerRing

	-- Progress fill (inner circle that grows)
	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.AnchorPoint = Vector2.new(0.5, 0.5)
	progressFill.Position = UDim2.new(0.5, 0, 0.5, 0)
	progressFill.Size = UDim2.new(0, 0, 0, 0)
	progressFill.BackgroundColor3 = Config.Extraction.ZoneColor
	progressFill.BackgroundTransparency = 0.4
	progressFill.Parent = outerRing

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = progressFill

	progressRing = progressFill

	-- Big countdown number
	local countdown = Instance.new("TextLabel")
	countdown.Name = "Countdown"
	countdown.Size = UDim2.new(1, 0, 0.6, 0)
	countdown.Position = UDim2.new(0, 0, 0.1, 0)
	countdown.BackgroundTransparency = 1
	countdown.Text = "5"
	countdown.Font = Enum.Font.FredokaOne
	countdown.TextSize = 72
	countdown.TextColor3 = Color3.new(1, 1, 1)
	countdown.TextStrokeTransparency = 0
	countdown.TextStrokeColor3 = Color3.fromRGB(0, 60, 30)
	countdown.Parent = ringContainer

	countdownLabel = countdown

	-- "EXTRACTING" label below
	local extractLabel = Instance.new("TextLabel")
	extractLabel.Name = "ExtractLabel"
	extractLabel.Size = UDim2.new(1, 0, 0, 24)
	extractLabel.Position = UDim2.new(0, 0, 0.72, 0)
	extractLabel.BackgroundTransparency = 1
	extractLabel.Text = "EXTRACTING"
	extractLabel.Font = Enum.Font.GothamBold
	extractLabel.TextSize = 16
	extractLabel.TextColor3 = Config.Extraction.ZoneColor
	extractLabel.TextStrokeTransparency = 0.3
	extractLabel.Parent = ringContainer

	-- White flash overlay (for extraction complete)
	local flash = Instance.new("Frame")
	flash.Name = "WhiteFlash"
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 10
	flash.Parent = gui

	whiteFlash = flash

	-- "EXTRACTED" slam text
	local slam = Instance.new("TextLabel")
	slam.Name = "SlamText"
	slam.Size = UDim2.new(1, 0, 0, 120)
	slam.Position = UDim2.new(0, 0, 0.35, 0)
	slam.BackgroundTransparency = 1
	slam.Text = "EXTRACTED"
	slam.Font = Enum.Font.FredokaOne
	slam.TextSize = 90
	slam.TextColor3 = Color3.fromRGB(0, 255, 130)
	slam.TextStrokeTransparency = 0
	slam.TextStrokeColor3 = Color3.fromRGB(0, 40, 20)
	slam.TextTransparency = 1
	slam.TextStrokeTransparency = 1
	slam.ZIndex = 11
	slam.Parent = gui

	slamText = slam

	screenGui = gui
end

local lastCountdownNum = -1

local function updateCountdown(progress: number)
	local remaining = math.ceil(Config.Extraction.Duration * (1 - progress))
	remaining = math.clamp(remaining, 0, Config.Extraction.Duration)

	countdownLabel.Text = tostring(remaining)

	-- Pop animation on number change
	if remaining ~= lastCountdownNum then
		lastCountdownNum = remaining
		countdownLabel.TextSize = 90
		TweenService:Create(countdownLabel, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
			TextSize = 72,
		}):Play()
	end

	-- Progress ring fill
	local fillSize = math.clamp(progress, 0, 1) * 160
	progressRing.Size = UDim2.new(0, fillSize, 0, fillSize)
end

local function playExtractionComplete()
	-- Hide countdown ring
	screenGui:FindFirstChild("RingContainer", true).Visible = false

	-- White flash
	whiteFlash.BackgroundTransparency = 0

	task.wait(0.3)

	-- Fade white slightly
	TweenService:Create(whiteFlash, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 0.3,
	}):Play()

	-- Slam text in (starts huge, scales down to final size)
	slamText.TextTransparency = 0
	slamText.TextStrokeTransparency = 0
	slamText.TextSize = 200
	slamText.Rotation = -5

	TweenService:Create(slamText, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextSize = 90,
		Rotation = 0,
	}):Play()

	task.wait(2)

	-- Fade everything out
	TweenService:Create(whiteFlash, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 1,
	}):Play()

	TweenService:Create(slamText, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	task.wait(0.5)
	screenGui.Enabled = false
end

function ExtractionClient.init()
	createExtractionUI()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	remotes:WaitForChild(RemoteNames.ExtractionStart).OnClientEvent:Connect(function()
		isExtracting = true
		lastCountdownNum = -1
		screenGui.Enabled = true

		-- Reset state
		local ringContainer = screenGui:FindFirstChild("RingContainer", true)
		if ringContainer then
			ringContainer.Visible = true
		end
		whiteFlash.BackgroundTransparency = 1
		slamText.TextTransparency = 1
		slamText.TextStrokeTransparency = 1
		progressRing.Size = UDim2.new(0, 0, 0, 0)
		countdownLabel.Text = tostring(Config.Extraction.Duration)
	end)

	remotes:WaitForChild(RemoteNames.ExtractionProgress).OnClientEvent:Connect(function(progress)
		if isExtracting then
			updateCountdown(progress)
		end
	end)

	remotes:WaitForChild(RemoteNames.ExtractionComplete).OnClientEvent:Connect(function()
		isExtracting = false
		task.spawn(playExtractionComplete)
	end)

	remotes:WaitForChild(RemoteNames.ExtractionCancel).OnClientEvent:Connect(function()
		isExtracting = false
		screenGui.Enabled = false
	end)
end

return ExtractionClient
