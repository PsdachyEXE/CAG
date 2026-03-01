--[[
	KillFeedClient — scrolling kill feed on the right side of screen.
	Shows [Killer] killed [Victim] entries.
	Color coded: white for AI kills, orange for player kills,
	red when local player is involved.
	Max 5 entries, each fades after 5 seconds.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local KillFeedClient = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local style = Config.UIStyle

local screenGui = nil
local feedContainer = nil
local entries = {} -- ordered list of entry frames

local function createKillFeedUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "KillFeedUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "FeedContainer"
	container.Size = UDim2.new(0, 300, 0, 200)
	container.AnchorPoint = Vector2.new(1, 0)
	container.Position = UDim2.new(1, -12, 0, 80)
	container.BackgroundTransparency = 1
	container.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	feedContainer = container
	screenGui = gui
	return gui
end

local function addEntry(data)
	if not feedContainer then
		return
	end

	-- Determine color
	local entryColor = style.TextPrimary -- white (AI kill default)
	local isLocalInvolved = (data.killer == player.Name or data.victim == player.Name)

	if isLocalInvolved then
		entryColor = style.Negative -- red
	elseif not data.isAI then
		entryColor = Color3.fromRGB(255, 180, 40) -- orange for player kills
	end

	-- Build text
	local text = data.killer .. "  ☠  " .. data.victim

	-- Create entry frame
	local frame = Instance.new("Frame")
	frame.Name = "Entry"
	frame.Size = UDim2.new(1, 0, 0, 24)
	frame.BackgroundColor3 = style.PanelBG
	frame.BackgroundTransparency = 0.3
	frame.LayoutOrder = #entries + 1
	frame.Parent = feedContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -12, 1, 0)
	label.Position = UDim2.new(0, 6, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = entryColor
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = frame

	-- Slide in animation
	frame.Position = UDim2.new(1, 0, 0, 0)
	TweenService:Create(frame, TweenInfo.new(style.SlideInTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0),
	}):Play()

	table.insert(entries, frame)

	-- Enforce max entries
	while #entries > Config.KillFeed.MaxEntries do
		local oldest = table.remove(entries, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end

	-- Re-order
	for i, entry in entries do
		entry.LayoutOrder = i
	end

	-- Fade and remove after lifetime
	task.spawn(function()
		task.wait(Config.KillFeed.EntryLifetime)

		TweenService:Create(frame, TweenInfo.new(0.3), {
			BackgroundTransparency = 1,
		}):Play()

		local lbl = frame:FindFirstChildOfClass("TextLabel")
		if lbl then
			TweenService:Create(lbl, TweenInfo.new(0.3), {
				TextTransparency = 1,
			}):Play()
		end

		task.wait(0.3)

		-- Remove from entries list
		for i, entry in entries do
			if entry == frame then
				table.remove(entries, i)
				break
			end
		end

		if frame.Parent then
			frame:Destroy()
		end
	end)
end

function KillFeedClient.init()
	createKillFeedUI()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	remotes:WaitForChild(RemoteNames.KillFeedEntry).OnClientEvent:Connect(function(data)
		addEntry(data)
	end)
end

return KillFeedClient
