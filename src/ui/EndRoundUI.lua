--[[
	EndRoundUI — shows the end-of-round screen.
	Displays whether the player extracted or died, XP placeholder, and loot placeholder.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local EndRoundUI = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = nil

local function createEndRoundScreen()
	local gui = Instance.new("ScreenGui")
	gui.Name = "EndRoundUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Enabled = false
	gui.Parent = playerGui

	-- Full-screen darkened background
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0.4
	bg.Parent = gui

	-- Main card
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.new(0, 500, 0, 400)
	card.Position = UDim2.new(0.5, -250, 0.5, -200)
	card.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	card.BackgroundTransparency = 0.1
	card.Parent = bg

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 16)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(80, 80, 120)
	cardStroke.Thickness = 2
	cardStroke.Parent = card

	-- Status header (EXTRACTED / ELIMINATED)
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 60)
	header.Position = UDim2.new(0, 0, 0, 20)
	header.BackgroundTransparency = 1
	header.Text = "EXTRACTED"
	header.Font = Enum.Font.GothamBold
	header.TextSize = 36
	header.TextColor3 = Color3.fromRGB(0, 255, 130)
	header.Parent = card

	-- Player name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.Size = UDim2.new(1, 0, 0, 30)
	nameLabel.Position = UDim2.new(0, 0, 0, 80)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = ""
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextSize = 18
	nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	nameLabel.Parent = card

	-- Divider
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(0.8, 0, 0, 2)
	divider.Position = UDim2.new(0.1, 0, 0, 120)
	divider.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	divider.BorderSizePixel = 0
	divider.Parent = card

	-- XP section
	local xpLabel = Instance.new("TextLabel")
	xpLabel.Name = "XPLabel"
	xpLabel.Size = UDim2.new(1, 0, 0, 30)
	xpLabel.Position = UDim2.new(0, 0, 0, 140)
	xpLabel.BackgroundTransparency = 1
	xpLabel.Text = "XP EARNED"
	xpLabel.Font = Enum.Font.GothamBold
	xpLabel.TextSize = 14
	xpLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
	xpLabel.Parent = card

	local xpValue = Instance.new("TextLabel")
	xpValue.Name = "XPValue"
	xpValue.Size = UDim2.new(1, 0, 0, 40)
	xpValue.Position = UDim2.new(0, 0, 0, 165)
	xpValue.BackgroundTransparency = 1
	xpValue.Text = "+100 XP"
	xpValue.Font = Enum.Font.GothamBold
	xpValue.TextSize = 28
	xpValue.TextColor3 = Color3.fromRGB(255, 220, 50)
	xpValue.Parent = card

	-- Loot section
	local lootHeader = Instance.new("TextLabel")
	lootHeader.Name = "LootHeader"
	lootHeader.Size = UDim2.new(1, 0, 0, 30)
	lootHeader.Position = UDim2.new(0, 0, 0, 220)
	lootHeader.BackgroundTransparency = 1
	lootHeader.Text = "LOOT"
	lootHeader.Font = Enum.Font.GothamBold
	lootHeader.TextSize = 14
	lootHeader.TextColor3 = Color3.fromRGB(150, 150, 180)
	lootHeader.Parent = card

	local lootList = Instance.new("TextLabel")
	lootList.Name = "LootList"
	lootList.Size = UDim2.new(0.8, 0, 0, 80)
	lootList.Position = UDim2.new(0.1, 0, 0, 250)
	lootList.BackgroundTransparency = 1
	lootList.Text = ""
	lootList.Font = Enum.Font.Gotham
	lootList.TextSize = 16
	lootList.TextColor3 = Color3.fromRGB(200, 200, 200)
	lootList.TextWrapped = true
	lootList.TextYAlignment = Enum.TextYAlignment.Top
	lootList.Parent = card

	-- Timer / auto-close text
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "Timer"
	timerLabel.Size = UDim2.new(1, 0, 0, 20)
	timerLabel.Position = UDim2.new(0, 0, 1, -30)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = ""
	timerLabel.Font = Enum.Font.Gotham
	timerLabel.TextSize = 12
	timerLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
	timerLabel.Parent = card

	screenGui = gui
	return gui
end

local function showEndRound(data)
	if not screenGui then
		return
	end

	local card = screenGui.Background.Card
	local header = card.Header
	local nameLabel = card.PlayerName
	local xpValue = card.XPValue
	local lootList = card.LootList
	local timerLabel = card.Timer

	-- Set extracted vs eliminated
	if data.extracted then
		header.Text = "EXTRACTED"
		header.TextColor3 = Color3.fromRGB(0, 255, 130)
	else
		header.Text = "ELIMINATED"
		header.TextColor3 = Color3.fromRGB(255, 60, 60)
	end

	nameLabel.Text = data.playerName or "Unknown"
	xpValue.Text = "+" .. tostring(data.xp or 0) .. " XP"

	-- Loot list
	if data.loot and #data.loot > 0 then
		local lootText = ""
		for i, item in data.loot do
			lootText = lootText .. "• " .. item
			if i < #data.loot then
				lootText = lootText .. "\n"
			end
		end
		lootList.Text = lootText
	else
		lootList.Text = "No loot this round"
	end

	-- Animate in
	local card_frame = card
	card_frame.Position = UDim2.new(0.5, -250, 0.6, 0)
	screenGui.Background.BackgroundTransparency = 1
	screenGui.Enabled = true

	-- Fade background
	TweenService:Create(
		screenGui.Background,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad),
		{ BackgroundTransparency = 0.4 }
	):Play()

	-- Slide card up
	TweenService:Create(
		card_frame,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, -250, 0.5, -200) }
	):Play()

	-- Countdown timer
	task.spawn(function()
		for remaining = Config.Round.EndScreenDuration, 1, -1 do
			timerLabel.Text = "Closing in " .. remaining .. "s..."
			task.wait(1)
		end

		-- Fade out
		TweenService:Create(
			screenGui.Background,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad),
			{ BackgroundTransparency = 1 }
		):Play()

		task.wait(0.3)
		screenGui.Enabled = false
	end)
end

function EndRoundUI.init()
	createEndRoundScreen()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	remotes:WaitForChild(RemoteNames.RoundEnd).OnClientEvent:Connect(function(data)
		showEndRound(data)
	end)
end

return EndRoundUI
