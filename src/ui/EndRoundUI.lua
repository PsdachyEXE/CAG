--[[
	EndRoundUI — cartoon-style results screen.
	Bold, chunky fonts. Bright colour palette (yellows, oranges, whites).
	Shows: status, XP (animated counter), wave reached, loot, streak, PLAY AGAIN button.
	Each element slides in with staggered animations.
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
local elements = {} -- tracked UI elements for animation

local function makeLabel(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = props.font or Enum.Font.FredokaOne
	label.TextSize = props.textSize or 24
	label.TextColor3 = props.color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = props.strokeTransparency or 0
	label.TextStrokeColor3 = props.strokeColor or Color3.fromRGB(30, 30, 30)
	label.Text = props.text or ""
	label.Size = props.size or UDim2.new(1, 0, 0, 40)
	label.Position = props.position or UDim2.new(0, 0, 0, 0)
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function createEndRoundScreen()
	local gui = Instance.new("ScreenGui")
	gui.Name = "EndRoundUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Enabled = false
	gui.Parent = playerGui

	-- Full-screen background
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	bg.BackgroundTransparency = 1
	bg.Parent = gui

	-- Main card (taller to fit wave row)
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Size = UDim2.new(0, 550, 0, 580)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
	card.BackgroundTransparency = 0.05
	card.Parent = bg

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 20)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(255, 180, 40)
	cardStroke.Thickness = 3
	cardStroke.Parent = card

	-- Status header
	local header = makeLabel(card, {
		text = "EXTRACTED",
		textSize = 52,
		color = Color3.fromRGB(0, 255, 130),
		strokeColor = Color3.fromRGB(0, 50, 25),
		size = UDim2.new(1, 0, 0, 70),
		position = UDim2.new(0, 0, 0, 20),
	})
	header.Name = "Header"

	-- Player name
	local nameLabel = makeLabel(card, {
		text = "",
		textSize = 20,
		font = Enum.Font.GothamBold,
		color = Color3.fromRGB(200, 200, 220),
		strokeTransparency = 0.5,
		size = UDim2.new(1, 0, 0, 28),
		position = UDim2.new(0, 0, 0, 90),
	})
	nameLabel.Name = "PlayerName"

	-- Divider
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(0.8, 0, 0, 3)
	divider.Position = UDim2.new(0.1, 0, 0, 128)
	divider.BackgroundColor3 = Color3.fromRGB(255, 180, 40)
	divider.BackgroundTransparency = 0.5
	divider.BorderSizePixel = 0
	divider.Parent = card

	-- XP section
	local xpTitle = makeLabel(card, {
		text = "XP EARNED",
		textSize = 14,
		font = Enum.Font.GothamBold,
		color = Color3.fromRGB(180, 180, 200),
		strokeTransparency = 0.6,
		size = UDim2.new(1, 0, 0, 22),
		position = UDim2.new(0, 0, 0, 145),
	})
	xpTitle.Name = "XPTitle"

	local xpValue = makeLabel(card, {
		text = "+0 XP",
		textSize = 40,
		color = Color3.fromRGB(255, 220, 50),
		strokeColor = Color3.fromRGB(100, 80, 0),
		size = UDim2.new(1, 0, 0, 50),
		position = UDim2.new(0, 0, 0, 165),
	})
	xpValue.Name = "XPValue"

	-- Wave reached section
	local waveTitle = makeLabel(card, {
		text = "WAVE REACHED",
		textSize = 14,
		font = Enum.Font.GothamBold,
		color = Color3.fromRGB(180, 180, 200),
		strokeTransparency = 0.6,
		size = UDim2.new(1, 0, 0, 22),
		position = UDim2.new(0, 0, 0, 225),
	})
	waveTitle.Name = "WaveTitle"

	local waveValue = makeLabel(card, {
		text = "Wave 1",
		textSize = 34,
		color = Color3.fromRGB(100, 200, 255),
		strokeColor = Color3.fromRGB(20, 60, 100),
		size = UDim2.new(1, 0, 0, 44),
		position = UDim2.new(0, 0, 0, 245),
	})
	waveValue.Name = "WaveValue"

	-- Streak section
	local streakTitle = makeLabel(card, {
		text = "STREAK",
		textSize = 14,
		font = Enum.Font.GothamBold,
		color = Color3.fromRGB(180, 180, 200),
		strokeTransparency = 0.6,
		size = UDim2.new(1, 0, 0, 22),
		position = UDim2.new(0, 0, 0, 295),
	})
	streakTitle.Name = "StreakTitle"

	local streakValue = makeLabel(card, {
		text = "x0",
		textSize = 34,
		color = Color3.fromRGB(255, 140, 40),
		strokeColor = Color3.fromRGB(100, 50, 0),
		size = UDim2.new(1, 0, 0, 44),
		position = UDim2.new(0, 0, 0, 315),
	})
	streakValue.Name = "StreakValue"

	-- Loot section
	local lootTitle = makeLabel(card, {
		text = "LOOT",
		textSize = 14,
		font = Enum.Font.GothamBold,
		color = Color3.fromRGB(180, 180, 200),
		strokeTransparency = 0.6,
		size = UDim2.new(1, 0, 0, 22),
		position = UDim2.new(0, 0, 0, 368),
	})
	lootTitle.Name = "LootTitle"

	local lootList = makeLabel(card, {
		text = "",
		textSize = 18,
		font = Enum.Font.GothamBold,
		color = Color3.fromRGB(230, 230, 240),
		strokeTransparency = 0.4,
		size = UDim2.new(0.8, 0, 0, 70),
		position = UDim2.new(0.1, 0, 0, 390),
	})
	lootList.Name = "LootList"
	lootList.TextYAlignment = Enum.TextYAlignment.Top

	-- PLAY AGAIN button
	local playBtn = Instance.new("TextButton")
	playBtn.Name = "PlayAgain"
	playBtn.Size = UDim2.new(0, 220, 0, 50)
	playBtn.Position = UDim2.new(0.5, -110, 1, -70)
	playBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 40)
	playBtn.Text = "PLAY AGAIN"
	playBtn.Font = Enum.Font.FredokaOne
	playBtn.TextSize = 26
	playBtn.TextColor3 = Color3.fromRGB(30, 20, 0)
	playBtn.TextStrokeTransparency = 1
	playBtn.AutoButtonColor = true
	playBtn.Parent = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 12)
	btnCorner.Parent = playBtn

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(200, 140, 20)
	btnStroke.Thickness = 2
	btnStroke.Parent = playBtn

	playBtn.MouseButton1Click:Connect(function()
		local btnRemotes = ReplicatedStorage:WaitForChild("RemoteEvents")
		local playAgainRemote = btnRemotes:FindFirstChild(RemoteNames.PlayAgain)
		if playAgainRemote then
			playAgainRemote:FireServer()
		end

		TweenService:Create(bg, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		task.wait(0.3)
		gui.Enabled = false
	end)

	-- Hover effect
	playBtn.MouseEnter:Connect(function()
		TweenService:Create(playBtn, TweenInfo.new(0.1), {
			Size = UDim2.new(0, 230, 0, 54),
			Position = UDim2.new(0.5, -115, 1, -72),
		}):Play()
	end)
	playBtn.MouseLeave:Connect(function()
		TweenService:Create(playBtn, TweenInfo.new(0.1), {
			Size = UDim2.new(0, 220, 0, 50),
			Position = UDim2.new(0.5, -110, 1, -70),
		}):Play()
	end)

	elements = {
		bg = bg,
		card = card,
		header = header,
		nameLabel = nameLabel,
		divider = divider,
		xpTitle = xpTitle,
		xpValue = xpValue,
		waveTitle = waveTitle,
		waveValue = waveValue,
		streakTitle = streakTitle,
		streakValue = streakValue,
		lootTitle = lootTitle,
		lootList = lootList,
		playBtn = playBtn,
	}

	screenGui = gui
	return gui
end

local function animateXPCounter(targetXP: number)
	local xpValue = elements.xpValue
	local duration = 1.2
	local startTime = tick()

	task.spawn(function()
		local current = 0
		while current < targetXP do
			local elapsed = tick() - startTime
			local t = math.clamp(elapsed / duration, 0, 1)
			t = 1 - (1 - t) ^ 3
			current = math.floor(t * targetXP)
			xpValue.Text = "+" .. tostring(current) .. " XP"
			task.wait()
		end
		xpValue.Text = "+" .. tostring(targetXP) .. " XP"
	end)
end

local function slideIn(element, delay: number, offsetY: number?)
	local targetPos = element.Position
	local startPos = UDim2.new(
		targetPos.X.Scale,
		targetPos.X.Offset,
		targetPos.Y.Scale,
		targetPos.Y.Offset + (offsetY or 30)
	)

	element.Position = startPos

	if element:IsA("TextLabel") or element:IsA("TextButton") then
		element.TextTransparency = 1
		element.TextStrokeTransparency = 1
	end

	task.spawn(function()
		task.wait(delay)

		TweenService:Create(element, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = targetPos,
		}):Play()

		if element:IsA("TextLabel") then
			TweenService:Create(element, TweenInfo.new(0.3), {
				TextTransparency = 0,
				TextStrokeTransparency = element == elements.header and 0 or 0.3,
			}):Play()
		elseif element:IsA("TextButton") then
			TweenService:Create(element, TweenInfo.new(0.3), {
				TextTransparency = 0,
			}):Play()
		end
	end)
end

local function showEndRound(data)
	if not screenGui then
		return
	end

	local bg = elements.bg
	local card = elements.card
	local header = elements.header
	local nameLabel = elements.nameLabel
	local xpValue = elements.xpValue
	local waveValue = elements.waveValue
	local streakValue = elements.streakValue
	local lootList = elements.lootList

	if data.extracted then
		header.Text = "EXTRACTED"
		header.TextColor3 = Color3.fromRGB(0, 255, 130)
		header.TextStrokeColor3 = Color3.fromRGB(0, 50, 25)
	else
		header.Text = "ELIMINATED"
		header.TextColor3 = Color3.fromRGB(255, 70, 70)
		header.TextStrokeColor3 = Color3.fromRGB(80, 15, 15)
	end

	nameLabel.Text = data.playerName or "Unknown"
	xpValue.Text = "+0 XP"
	waveValue.Text = "Wave " .. tostring(data.waveReached or 1)
	streakValue.Text = "x" .. tostring(data.streak or 0)

	if data.loot and #data.loot > 0 then
		local lines = {}
		for _, item in data.loot do
			table.insert(lines, "  " .. item)
		end
		lootList.Text = table.concat(lines, "\n")
	else
		lootList.Text = "No loot this round"
	end

	bg.BackgroundTransparency = 1
	card.Position = UDim2.new(0.5, 0, 0.6, 0)
	screenGui.Enabled = true

	TweenService:Create(bg, TweenInfo.new(0.4), { BackgroundTransparency = 0.3 }):Play()

	TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
	}):Play()

	slideIn(header, 0.3)
	slideIn(nameLabel, 0.4)
	slideIn(elements.xpTitle, 0.5)
	slideIn(xpValue, 0.55)
	slideIn(elements.waveTitle, 0.65)
	slideIn(waveValue, 0.7)
	slideIn(elements.streakTitle, 0.8)
	slideIn(streakValue, 0.85)
	slideIn(elements.lootTitle, 0.95)
	slideIn(lootList, 1.0)
	slideIn(elements.playBtn, 1.15)

	task.spawn(function()
		task.wait(0.7)
		animateXPCounter(data.xp or 0)
	end)

	task.spawn(function()
		task.wait(Config.Round.EndScreenDuration)
		if screenGui.Enabled then
			TweenService:Create(bg, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			task.wait(0.3)
			screenGui.Enabled = false
		end
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
