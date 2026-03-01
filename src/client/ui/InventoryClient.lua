--[[
	InventoryClient — Tab key toggles volatile inventory panel.
	2x2 grid with rarity-coloured borders.
	Also handles loot toast notifications and inventory-full feedback.
	No separate notification module needed — toasts built in.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local InventoryClient = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PANEL_BG = Color3.fromRGB(26, 26, 46)    -- #1A1A2E
local BORDER_RED = Color3.fromRGB(233, 69, 96)  -- #E94560
local SLOT_EMPTY_BG = Color3.fromRGB(40, 40, 55)
local SLOT_EMPTY_BORDER = Color3.fromRGB(80, 80, 100)
local TEXT_WHITE = Color3.new(1, 1, 1)
local TEXT_GREY = Color3.fromRGB(140, 140, 155)

local RARITY_COLORS = {
	Common = Color3.fromRGB(155, 155, 155),       -- #9B9B9B
	Uncommon = Color3.fromRGB(76, 175, 80),        -- #4CAF50
	Rare = Color3.fromRGB(33, 150, 243),           -- #2196F3
	Epic = Color3.fromRGB(156, 39, 176),           -- #9C27B0
	Legendary = Color3.fromRGB(255, 152, 0),       -- #FF9800
}

local screenGui = nil
local panel = nil
local isOpen = false
local volatileItems = {}  -- synced array of items from server

-- ── Toast system ─────────────────────────────────────────

local toastGui = nil
local activeToasts = {}

local function createToastGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ToastUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 25
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	toastGui = gui
end

local function showToast(text: string, color: Color3)
	if not toastGui then
		return
	end

	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(0, 220, 0, 36)
	toast.AnchorPoint = Vector2.new(1, 1)
	toast.Position = UDim2.new(1, -16, 1, -16 - (#activeToasts * 44))
	toast.BackgroundColor3 = PANEL_BG
	toast.BackgroundTransparency = 0.15
	toast.Parent = toastGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = toast

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 1.5
	stroke.Parent = toast

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -12, 1, 0)
	label.Position = UDim2.new(0, 6, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = toast

	-- Slide in from right
	local targetX = toast.Position
	toast.Position = UDim2.new(1, 240, targetX.Y.Scale, targetX.Y.Offset)
	TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = targetX,
	}):Play()

	table.insert(activeToasts, toast)

	-- Hold then fade out
	task.spawn(function()
		task.wait(2.5)

		TweenService:Create(toast, TweenInfo.new(0.3), {
			Position = UDim2.new(1, 240, targetX.Y.Scale, targetX.Y.Offset),
			BackgroundTransparency = 1,
		}):Play()

		local labelRef = toast:FindFirstChildOfClass("TextLabel")
		if labelRef then
			TweenService:Create(labelRef, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		end

		task.wait(0.3)

		-- Remove from activeToasts
		for i, t in activeToasts do
			if t == toast then
				table.remove(activeToasts, i)
				break
			end
		end
		toast:Destroy()

		-- Reposition remaining toasts
		for i, t in activeToasts do
			local yOff = -16 - ((i - 1) * 44)
			TweenService:Create(t, TweenInfo.new(0.15), {
				Position = UDim2.new(1, -16, 1, yOff),
			}):Play()
		end
	end)
end

-- ── Inventory panel ──────────────────────────────────────

local function createPanel()
	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = playerGui

	-- Main panel
	local p = Instance.new("Frame")
	p.Name = "Panel"
	p.Size = UDim2.new(0, 240, 0, 280)
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.new(0.5, 0, 0.5, 60) -- start off-screen (below)
	p.BackgroundColor3 = PANEL_BG
	p.BackgroundTransparency = 0.15
	p.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = p

	local stroke = Instance.new("UIStroke")
	stroke.Color = BORDER_RED
	stroke.Thickness = 2
	stroke.Parent = p

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 32)
	title.BackgroundTransparency = 1
	title.Text = "INVENTORY"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 18
	title.TextColor3 = TEXT_WHITE
	title.Parent = p

	-- Subtitle
	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -16, 0, 14)
	sub.Position = UDim2.new(0, 8, 0, 32)
	sub.BackgroundTransparency = 1
	sub.Text = "VOLATILE (lost on death)"
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 10
	sub.TextColor3 = TEXT_GREY
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Parent = p

	-- 2x2 grid
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.Size = UDim2.new(1, -24, 0, 180)
	grid.Position = UDim2.new(0, 12, 0, 52)
	grid.BackgroundTransparency = 1
	grid.Parent = p

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 100, 0, 82)
	gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	-- Create 4 slots
	for i = 1, Config.MAX_VOLATILE_SLOTS do
		local slot = Instance.new("Frame")
		slot.Name = "Slot_" .. i
		slot.LayoutOrder = i
		slot.BackgroundColor3 = SLOT_EMPTY_BG
		slot.BackgroundTransparency = 0.2
		slot.Parent = grid

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 6)
		slotCorner.Parent = slot

		local slotStroke = Instance.new("UIStroke")
		slotStroke.Name = "RarityBorder"
		slotStroke.Color = SLOT_EMPTY_BORDER
		slotStroke.Thickness = 2
		slotStroke.Parent = slot

		-- Dashed appearance for empty (simulated via lower opacity)
		-- Full stroke for filled items

		-- Item name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "ItemName"
		nameLabel.Size = UDim2.new(1, -8, 0, 18)
		nameLabel.Position = UDim2.new(0, 4, 0, 8)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = "Empty"
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 12
		nameLabel.TextColor3 = TEXT_GREY
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = slot

		-- Rarity label
		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Name = "Rarity"
		rarityLabel.Size = UDim2.new(1, -8, 0, 14)
		rarityLabel.Position = UDim2.new(0, 4, 0, 28)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Text = ""
		rarityLabel.Font = Enum.Font.Gotham
		rarityLabel.TextSize = 10
		rarityLabel.TextColor3 = TEXT_GREY
		rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
		rarityLabel.Parent = slot
	end

	panel = p
	screenGui = gui
end

local function refreshSlots()
	if not panel then
		return
	end

	local grid = panel:FindFirstChild("Grid")
	if not grid then
		return
	end

	for i = 1, Config.MAX_VOLATILE_SLOTS do
		local slot = grid:FindFirstChild("Slot_" .. i)
		if not slot then
			continue
		end

		local item = volatileItems[i]
		local nameLabel = slot:FindFirstChild("ItemName")
		local rarityLabel = slot:FindFirstChild("Rarity")
		local border = slot:FindFirstChild("RarityBorder")

		if item then
			local rarityColor = RARITY_COLORS[item.rarity] or RARITY_COLORS.Common

			if nameLabel then
				nameLabel.Text = item.name or "Unknown"
				nameLabel.TextColor3 = TEXT_WHITE
			end
			if rarityLabel then
				rarityLabel.Text = item.rarity or ""
				rarityLabel.TextColor3 = rarityColor
			end
			if border then
				border.Color = rarityColor
			end
		else
			if nameLabel then
				nameLabel.Text = "Empty"
				nameLabel.TextColor3 = TEXT_GREY
			end
			if rarityLabel then
				rarityLabel.Text = ""
			end
			if border then
				border.Color = SLOT_EMPTY_BORDER
			end
		end
	end
end

local function openPanel()
	if isOpen or not screenGui then
		return
	end
	isOpen = true
	screenGui.Enabled = true
	refreshSlots()

	-- Slide in from bottom
	panel.Position = UDim2.new(0.5, 0, 0.5, 60)
	TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
	}):Play()
end

local function closePanel()
	if not isOpen or not screenGui then
		return
	end
	isOpen = false

	-- Slide out to bottom
	TweenService:Create(panel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, 0.5, 60),
	}):Play()

	task.spawn(function()
		task.wait(0.15)
		if not isOpen then
			screenGui.Enabled = false
		end
	end)
end

function InventoryClient.init()
	createPanel()
	createToastGui()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	-- Tab key toggle
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Tab then
			if isOpen then
				closePanel()
			else
				openPanel()
			end
		end
	end)

	-- LootReceived — add item to local inventory + show toast
	remotes:WaitForChild(RemoteNames.LootReceived).OnClientEvent:Connect(function(item)
		if item then
			table.insert(volatileItems, item)
			if isOpen then
				refreshSlots()
			end

			-- Toast notification
			local rarityColor = RARITY_COLORS[item.rarity] or RARITY_COLORS.Common
			showToast(item.name .. " [" .. (item.rarity or "?") .. "]", rarityColor)
		end
	end)

	-- InteractFailed — show red toast
	remotes:WaitForChild(RemoteNames.InteractFailed).OnClientEvent:Connect(function(reason)
		if reason == "INVENTORY_FULL" then
			showToast("Inventory Full", Color3.fromRGB(244, 67, 54))
		end
	end)

	print("[CAG] InventoryClient initialized")
end

return InventoryClient
