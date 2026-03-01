--[[
	LeaderboardClient — Tab key toggles mid-match leaderboard.
	Columns: Rank, Player, Kills, Items, Status.
	Sorted by kills descending. Squad members highlighted.
	Updates in real-time via remote.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local LeaderboardClient = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local style = Config.UIStyle

local screenGui = nil
local boardFrame = nil
local isVisible = false
local leaderboardData = {} -- updated via remote

local function createLeaderboardUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LeaderboardUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = playerGui

	-- Semi-transparent overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.6
	overlay.Parent = gui

	-- Board frame
	local board = Instance.new("Frame")
	board.Name = "Board"
	board.Size = UDim2.new(0, 500, 0, 400)
	board.AnchorPoint = Vector2.new(0.5, 0.5)
	board.Position = UDim2.new(0.5, 0, 0.5, 0)
	board.BackgroundColor3 = style.PanelBG
	board.BackgroundTransparency = 0.05
	board.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = style.CornerRadius
	corner.Parent = board

	local stroke = Instance.new("UIStroke")
	stroke.Color = style.PanelBorderRed
	stroke.Thickness = 2
	stroke.Parent = board

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "LEADERBOARD"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 24
	title.TextColor3 = style.TextPrimary
	title.Parent = board

	-- Header row
	local headerY = 44
	local headers = { "RANK", "PLAYER", "KILLS", "ITEMS", "STATUS" }
	local widths = { 0.08, 0.30, 0.15, 0.15, 0.25 }
	local xOffset = 0.04

	for i, headerText in headers do
		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(widths[i], 0, 0, 22)
		header.Position = UDim2.new(xOffset, 0, 0, headerY)
		header.BackgroundTransparency = 1
		header.Text = headerText
		header.Font = Enum.Font.GothamBold
		header.TextSize = 11
		header.TextColor3 = style.TextSecondary
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Parent = board
		xOffset = xOffset + widths[i]
	end

	-- Divider
	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(0.92, 0, 0, 1)
	divider.Position = UDim2.new(0.04, 0, 0, headerY + 24)
	divider.BackgroundColor3 = style.PanelBorderRed
	divider.BackgroundTransparency = 0.5
	divider.BorderSizePixel = 0
	divider.Parent = board

	-- Rows container
	local rowContainer = Instance.new("Frame")
	rowContainer.Name = "Rows"
	rowContainer.Size = UDim2.new(0.92, 0, 1, -(headerY + 30))
	rowContainer.Position = UDim2.new(0.04, 0, 0, headerY + 28)
	rowContainer.BackgroundTransparency = 1
	rowContainer.ClipsDescendants = true
	rowContainer.Parent = board

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rowContainer

	boardFrame = board
	screenGui = gui
	return gui
end

local function refreshBoard(data)
	if not boardFrame then
		return
	end

	local rowContainer = boardFrame:FindFirstChild("Rows")
	if not rowContainer then
		return
	end

	-- Clear old rows
	for _, child in rowContainer:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Sort by kills descending
	local sorted = {}
	for _, entry in data do
		table.insert(sorted, entry)
	end
	table.sort(sorted, function(a, b)
		return (a.kills or 0) > (b.kills or 0)
	end)

	local widths = { 0.08, 0.30, 0.15, 0.15, 0.25 }

	for rank, entry in sorted do
		local row = Instance.new("Frame")
		row.Name = "Row_" .. rank
		row.Size = UDim2.new(1, 0, 0, 26)
		row.BackgroundTransparency = rank % 2 == 0 and 0.85 or 1
		row.BackgroundColor3 = style.PanelBG
		row.LayoutOrder = rank
		row.Parent = rowContainer

		-- Highlight if local player
		local textColor = style.TextPrimary
		if entry.name == player.Name then
			textColor = style.Highlight
			row.BackgroundTransparency = 0.7
			row.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
		end

		local values = {
			tostring(rank),
			entry.name or "?",
			tostring(entry.kills or 0),
			tostring(entry.items or 0),
			entry.status or "In Match",
		}

		local xOff = 0
		for i, value in values do
			local cell = Instance.new("TextLabel")
			cell.Size = UDim2.new(widths[i], 0, 1, 0)
			cell.Position = UDim2.new(xOff, 0, 0, 0)
			cell.BackgroundTransparency = 1
			cell.Text = value
			cell.Font = i == 2 and Enum.Font.GothamBold or Enum.Font.Gotham
			cell.TextSize = 13
			cell.TextColor3 = textColor
			cell.TextXAlignment = Enum.TextXAlignment.Left
			cell.Parent = row
			xOff = xOff + widths[i]
		end

		-- Status color
		if entry.status == "Extracted" then
			local statusCell = row:GetChildren()
			for _, child in row:GetChildren() do
				if child:IsA("TextLabel") and child.Text == "Extracted" then
					child.TextColor3 = style.Positive
				end
			end
		elseif entry.status == "Eliminated" then
			for _, child in row:GetChildren() do
				if child:IsA("TextLabel") and child.Text == "Eliminated" then
					child.TextColor3 = style.Negative
				end
			end
		end
	end
end

function LeaderboardClient.init()
	createLeaderboardUI()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	-- Tab toggle
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Tab then
			isVisible = not isVisible
			if screenGui then
				screenGui.Enabled = isVisible
			end
		end
	end)

	-- Auto-hide on release (hold to view)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Tab then
			isVisible = false
			if screenGui then
				screenGui.Enabled = false
			end
		end
	end)

	-- Leaderboard data updates
	remotes:WaitForChild(RemoteNames.LeaderboardUpdate).OnClientEvent:Connect(function(data)
		leaderboardData = data
		if isVisible then
			refreshBoard(data)
		end
	end)

	-- Refresh when shown
	-- Also listen for round state to clear
	remotes:WaitForChild(RemoteNames.RoundStateChanged).OnClientEvent:Connect(function(state)
		if state == "Waiting" then
			leaderboardData = {}
		end
	end)
end

return LeaderboardClient
