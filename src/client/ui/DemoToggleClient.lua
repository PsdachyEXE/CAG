--[[
	DemoToggleClient — dev panel in top-left corner.
	Toggles:
	  1. Demo Mode ON/OFF (fires DemoModeChanged to server)
	  2. Leaderboard show/hide (calls LeaderboardClient.toggle)
	Always visible during play.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local DemoToggleClient = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local style = Config.UIStyle

local LeaderboardClient = nil -- set via init param

local demoModeOn = Config.isDemoMode
local screenGui = nil

local function createToggleRow(parent, labelText, yOffset, defaultOn, onToggle)
	local row = Instance.new("Frame")
	row.Name = labelText:gsub(" ", "")
	row.Size = UDim2.new(1, -16, 0, 28)
	row.Position = UDim2.new(0, 8, 0, yOffset)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -56, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = style.TextPrimary
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	-- Toggle switch (pill shape)
	local toggleBG = Instance.new("Frame")
	toggleBG.Name = "ToggleBG"
	toggleBG.Size = UDim2.new(0, 44, 0, 22)
	toggleBG.AnchorPoint = Vector2.new(1, 0.5)
	toggleBG.Position = UDim2.new(1, 0, 0.5, 0)
	toggleBG.BackgroundColor3 = defaultOn and style.Positive or Color3.fromRGB(80, 80, 100)
	toggleBG.Parent = row

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 11)
	toggleCorner.Parent = toggleBG

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 18, 0, 18)
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Position = defaultOn and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Parent = toggleBG

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(0, 9)
	knobCorner.Parent = knob

	local isOn = defaultOn

	-- Clickable button overlay
	local btn = Instance.new("TextButton")
	btn.Name = "HitArea"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = row

	btn.MouseButton1Click:Connect(function()
		isOn = not isOn

		local targetPos = isOn and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
		local targetColor = isOn and style.Positive or Color3.fromRGB(80, 80, 100)

		TweenService:Create(knob, TweenInfo.new(0.15), { Position = targetPos }):Play()
		TweenService:Create(toggleBG, TweenInfo.new(0.15), { BackgroundColor3 = targetColor }):Play()

		if onToggle then
			onToggle(isOn)
		end
	end)

	return row, function() return isOn end
end

local function createPanel()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DemoToggleUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	-- Panel background
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 180, 0, 120)
	panel.Position = UDim2.new(0, 12, 0, 12)
	panel.BackgroundColor3 = Color3.fromRGB(26, 26, 46) -- #1A1A2E
	panel.BackgroundTransparency = 0.15
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = style.PanelBorderRed
	stroke.Thickness = 1
	stroke.Parent = panel

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 28)
	title.BackgroundTransparency = 1
	title.Text = "DEV PANEL"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 14
	title.TextColor3 = style.TextPrimary
	title.Parent = panel

	-- Divider under title
	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(0.85, 0, 0, 1)
	divider.AnchorPoint = Vector2.new(0.5, 0)
	divider.Position = UDim2.new(0.5, 0, 0, 28)
	divider.BackgroundColor3 = style.PanelBorderRed
	divider.BackgroundTransparency = 0.5
	divider.BorderSizePixel = 0
	divider.Parent = panel

	-- Demo Mode toggle (row 1)
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local demoRemote = remotes:WaitForChild(RemoteNames.DemoModeChanged)

	createToggleRow(panel, "Demo Mode", 36, demoModeOn, function(isOn)
		demoModeOn = isOn
		demoRemote:FireServer(isOn)
	end)

	-- Leaderboard toggle (row 2)
	createToggleRow(panel, "Leaderboard", 70, false, function(_isOn)
		if LeaderboardClient and LeaderboardClient.toggle then
			LeaderboardClient.toggle()
		end
	end)

	screenGui = gui
	return gui
end

function DemoToggleClient.init(leaderboardClientRef)
	LeaderboardClient = leaderboardClientRef
	createPanel()
	print("[CAG] DemoToggleClient initialized")
end

return DemoToggleClient
