--[[
	NotificationClient — toast notification system (bottom-right).
	Types: loot (green), airdrop (yellow), squad (blue),
	eliminated (red), xp (white), level_up (gold full-screen).
	Max 4 visible, slide in/out, 3s hold.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local NotificationClient = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local style = Config.UIStyle

local screenGui = nil
local toastContainer = nil
local activeToasts = {}

local TYPE_COLORS = {
	loot = Color3.fromRGB(76, 175, 80),
	airdrop = Color3.fromRGB(255, 200, 40),
	squad = Color3.fromRGB(33, 150, 243),
	eliminated = Color3.fromRGB(244, 67, 54),
	xp = Color3.fromRGB(255, 255, 255),
	level_up = Color3.fromRGB(255, 200, 50),
	warning = Color3.fromRGB(255, 140, 40),
	info = Color3.fromRGB(200, 200, 220),
}

local function createNotificationUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "NotificationUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 11
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "ToastContainer"
	container.Size = UDim2.new(0, 300, 0, 400)
	container.AnchorPoint = Vector2.new(1, 1)
	container.Position = UDim2.new(1, -12, 1, -60)
	container.BackgroundTransparency = 1
	container.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	toastContainer = container
	screenGui = gui
	return gui
end

local function showToast(notifType: string, text: string, subText: string?)
	if not toastContainer then
		return
	end

	local accentColor = TYPE_COLORS[notifType] or TYPE_COLORS.info

	local toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.Size = UDim2.new(1, 0, 0, subText and 52 or 38)
	toast.BackgroundColor3 = style.PanelBG
	toast.BackgroundTransparency = 0.05
	toast.LayoutOrder = tick() * 1000 -- order by time
	toast.Parent = toastContainer

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = style.CornerRadius
	tCorner.Parent = toast

	local tStroke = Instance.new("UIStroke")
	tStroke.Color = accentColor
	tStroke.Thickness = 2
	tStroke.Transparency = 0.3
	tStroke.Parent = toast

	-- Accent bar on left
	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 4, 1, -8)
	accent.Position = UDim2.new(0, 6, 0, 4)
	accent.BackgroundColor3 = accentColor
	accent.BorderSizePixel = 0
	accent.Parent = toast

	local acCorner = Instance.new("UICorner")
	acCorner.CornerRadius = UDim.new(0, 2)
	acCorner.Parent = accent

	-- Main text
	local mainText = Instance.new("TextLabel")
	mainText.Size = UDim2.new(1, -24, 0, 20)
	mainText.Position = UDim2.new(0, 18, 0, subText and 6 or 9)
	mainText.BackgroundTransparency = 1
	mainText.Text = text
	mainText.Font = Enum.Font.GothamBold
	mainText.TextSize = 14
	mainText.TextColor3 = accentColor
	mainText.TextXAlignment = Enum.TextXAlignment.Left
	mainText.TextTruncate = Enum.TextTruncate.AtEnd
	mainText.Parent = toast

	-- Sub text
	if subText then
		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, -24, 0, 16)
		sub.Position = UDim2.new(0, 18, 0, 28)
		sub.BackgroundTransparency = 1
		sub.Text = subText
		sub.Font = Enum.Font.Gotham
		sub.TextSize = 11
		sub.TextColor3 = style.TextSecondary
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.TextTruncate = Enum.TextTruncate.AtEnd
		sub.Parent = toast
	end

	-- Slide in from right
	toast.Position = UDim2.new(1, 0, 0, 0)
	TweenService:Create(toast, TweenInfo.new(Config.Notification.SlideInDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0),
	}):Play()

	table.insert(activeToasts, toast)

	-- Enforce max visible
	while #activeToasts > Config.Notification.MaxVisible do
		local oldest = table.remove(activeToasts, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end

	-- Auto-remove after hold duration
	task.spawn(function()
		task.wait(Config.Notification.HoldDuration)

		TweenService:Create(toast, TweenInfo.new(Config.Notification.SlideOutDuration), {
			Position = UDim2.new(1, 0, 0, 0),
		}):Play()

		task.wait(Config.Notification.SlideOutDuration)

		for i, t in activeToasts do
			if t == toast then
				table.remove(activeToasts, i)
				break
			end
		end

		if toast.Parent then
			toast:Destroy()
		end
	end)
end

local function showLevelUp(level: number)
	if not screenGui then
		return
	end

	-- Full-screen gold flash
	local flash = Instance.new("Frame")
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	flash.BackgroundTransparency = 0.5
	flash.ZIndex = 100
	flash.Parent = screenGui

	local levelText = Instance.new("TextLabel")
	levelText.Size = UDim2.new(1, 0, 0, 80)
	levelText.AnchorPoint = Vector2.new(0.5, 0.5)
	levelText.Position = UDim2.new(0.5, 0, 0.4, 0)
	levelText.BackgroundTransparency = 1
	levelText.Text = "LEVEL UP!"
	levelText.Font = Enum.Font.FredokaOne
	levelText.TextSize = 64
	levelText.TextColor3 = Color3.fromRGB(255, 220, 50)
	levelText.TextStrokeTransparency = 0
	levelText.TextStrokeColor3 = Color3.fromRGB(100, 70, 0)
	levelText.ZIndex = 101
	levelText.Parent = screenGui

	local levelNum = Instance.new("TextLabel")
	levelNum.Size = UDim2.new(1, 0, 0, 50)
	levelNum.AnchorPoint = Vector2.new(0.5, 0.5)
	levelNum.Position = UDim2.new(0.5, 0, 0.5, 0)
	levelNum.BackgroundTransparency = 1
	levelNum.Text = "Level " .. level
	levelNum.Font = Enum.Font.FredokaOne
	levelNum.TextSize = 36
	levelNum.TextColor3 = Color3.new(1, 1, 1)
	levelNum.TextStrokeTransparency = 0
	levelNum.TextStrokeColor3 = Color3.fromRGB(50, 50, 50)
	levelNum.ZIndex = 101
	levelNum.Parent = screenGui

	-- Scale in
	levelText.TextSize = 20
	TweenService:Create(levelText, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextSize = 64,
	}):Play()

	-- Fade out
	task.spawn(function()
		task.wait(2)
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(levelText, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(levelNum, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.5)
		flash:Destroy()
		levelText:Destroy()
		levelNum:Destroy()
	end)
end

function NotificationClient.show(notifType: string, text: string, subText: string?)
	showToast(notifType, text, subText)
end

function NotificationClient.init()
	createNotificationUI()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	-- Generic notification from server
	remotes:WaitForChild(RemoteNames.ShowNotification).OnClientEvent:Connect(function(data)
		showToast(data.type or "info", data.text or "", data.subText)
	end)

	-- Loot received
	remotes:WaitForChild(RemoteNames.LootReceived).OnClientEvent:Connect(function(item)
		showToast("loot", item.name, item.rarity .. " " .. item.type)
	end)

	-- XP gained
	remotes:WaitForChild(RemoteNames.XPGained).OnClientEvent:Connect(function(amount, _currentXP, _xpNeeded)
		showToast("xp", "+" .. amount .. " XP")
	end)

	-- Level up
	remotes:WaitForChild(RemoteNames.LevelUp).OnClientEvent:Connect(function(newLevel)
		showLevelUp(newLevel)
	end)

	-- Player eliminated
	remotes:WaitForChild(RemoteNames.PlayerEliminated).OnClientEvent:Connect(function(data)
		showToast("eliminated", data.playerName .. " eliminated", "by " .. (data.killerName or "AI"))
	end)

	-- Volatile items lost
	remotes:WaitForChild(RemoteNames.VolatileItemsLost).OnClientEvent:Connect(function(items)
		if items and #items > 0 then
			showToast("eliminated", "Items lost!", #items .. " item(s) destroyed")
		end
	end)

	-- Volatile items extracted
	remotes:WaitForChild(RemoteNames.VolatileItemsExtracted).OnClientEvent:Connect(function(items)
		if items and #items > 0 then
			showToast("loot", "Items extracted!", #items .. " item(s) saved")
		end
	end)
end

return NotificationClient
