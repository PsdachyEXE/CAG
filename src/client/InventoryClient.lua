--[[
	InventoryClient — volatile inventory panel (I key or Tab fallback).
	2x2 grid showing volatile items with rarity-colored borders.
	Also displays equipped weapon, level, XP bar, currency.
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
local style = Config.UIStyle

local screenGui = nil
local inventoryPanel = nil
local isOpen = false
local volatileItems = {} -- updated via remote

local function getRarityColor(rarity: string): Color3
	return style.RarityColors[rarity] or style.RarityColors.Common
end

local function createInventoryUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = playerGui

	-- Overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.6
	overlay.Parent = gui

	-- Main panel
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 400, 0, 380)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.BackgroundColor3 = style.PanelBG
	panel.BackgroundTransparency = 0.05
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = style.CornerRadius
	corner.Parent = panel

	local pStroke = Instance.new("UIStroke")
	pStroke.Color = style.PanelBorderRed
	pStroke.Thickness = 2
	pStroke.Parent = panel

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Text = "INVENTORY"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 24
	title.TextColor3 = style.TextPrimary
	title.Parent = panel

	-- Volatile section label
	local volLabel = Instance.new("TextLabel")
	volLabel.Size = UDim2.new(1, -24, 0, 20)
	volLabel.Position = UDim2.new(0, 12, 0, 40)
	volLabel.BackgroundTransparency = 1
	volLabel.Text = "VOLATILE LOOT (lost on death)"
	volLabel.Font = Enum.Font.GothamBold
	volLabel.TextSize = 11
	volLabel.TextColor3 = style.TextSecondary
	volLabel.TextXAlignment = Enum.TextXAlignment.Left
	volLabel.Parent = panel

	-- 2x2 grid for volatile items
	local gridFrame = Instance.new("Frame")
	gridFrame.Name = "Grid"
	gridFrame.Size = UDim2.new(1, -24, 0, 200)
	gridFrame.Position = UDim2.new(0, 12, 0, 64)
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = panel

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 175, 0, 90)
	gridLayout.CellPadding = UDim2.new(0, 12, 0, 12)
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.Parent = gridFrame

	-- Create 4 slots
	for i = 1, Config.Inventory.MaxVolatileSlots do
		local slot = Instance.new("Frame")
		slot.Name = "Slot_" .. i
		slot.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
		slot.BackgroundTransparency = 0.2
		slot.Parent = gridFrame

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 6)
		slotCorner.Parent = slot

		local slotStroke = Instance.new("UIStroke")
		slotStroke.Name = "RarityBorder"
		slotStroke.Color = Color3.fromRGB(60, 60, 80)
		slotStroke.Thickness = 2
		slotStroke.Parent = slot

		-- Item name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "ItemName"
		nameLabel.Size = UDim2.new(1, -8, 0, 20)
		nameLabel.Position = UDim2.new(0, 4, 0, 8)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = "Empty"
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 13
		nameLabel.TextColor3 = style.TextSecondary
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = slot

		-- Rarity label
		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Name = "Rarity"
		rarityLabel.Size = UDim2.new(1, -8, 0, 14)
		rarityLabel.Position = UDim2.new(0, 4, 0, 30)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Text = ""
		rarityLabel.Font = Enum.Font.Gotham
		rarityLabel.TextSize = 10
		rarityLabel.TextColor3 = style.TextSecondary
		rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
		rarityLabel.Parent = slot

		-- Value
		local valueLabel = Instance.new("TextLabel")
		valueLabel.Name = "Value"
		valueLabel.Size = UDim2.new(1, -8, 0, 16)
		valueLabel.Position = UDim2.new(0, 4, 1, -22)
		valueLabel.BackgroundTransparency = 1
		valueLabel.Text = ""
		valueLabel.Font = Enum.Font.FredokaOne
		valueLabel.TextSize = 14
		valueLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.Parent = slot
	end

	-- Persistent info section
	local persistLabel = Instance.new("TextLabel")
	persistLabel.Size = UDim2.new(1, -24, 0, 20)
	persistLabel.Position = UDim2.new(0, 12, 0, 275)
	persistLabel.BackgroundTransparency = 1
	persistLabel.Text = "PROFILE"
	persistLabel.Font = Enum.Font.GothamBold
	persistLabel.TextSize = 11
	persistLabel.TextColor3 = style.TextSecondary
	persistLabel.TextXAlignment = Enum.TextXAlignment.Left
	persistLabel.Parent = panel

	local profileInfo = Instance.new("TextLabel")
	profileInfo.Name = "ProfileInfo"
	profileInfo.Size = UDim2.new(1, -24, 0, 60)
	profileInfo.Position = UDim2.new(0, 12, 0, 298)
	profileInfo.BackgroundTransparency = 1
	profileInfo.Text = "Level 1 | 0 XP | 0 Credits"
	profileInfo.Font = Enum.Font.Gotham
	profileInfo.TextSize = 14
	profileInfo.TextColor3 = style.TextPrimary
	profileInfo.TextXAlignment = Enum.TextXAlignment.Left
	profileInfo.TextYAlignment = Enum.TextYAlignment.Top
	profileInfo.TextWrapped = true
	profileInfo.Parent = panel

	inventoryPanel = panel
	screenGui = gui
	return gui
end

local function refreshSlots()
	if not inventoryPanel then
		return
	end

	local grid = inventoryPanel:FindFirstChild("Grid")
	if not grid then
		return
	end

	for i = 1, Config.Inventory.MaxVolatileSlots do
		local slot = grid:FindFirstChild("Slot_" .. i)
		if not slot then
			continue
		end

		local item = volatileItems[i]
		local nameLabel = slot:FindFirstChild("ItemName")
		local rarityLabel = slot:FindFirstChild("Rarity")
		local valueLabel = slot:FindFirstChild("Value")
		local border = slot:FindFirstChild("RarityBorder")

		if item then
			if nameLabel then
				nameLabel.Text = item.name or item.itemID or "Unknown"
				nameLabel.TextColor3 = style.TextPrimary
			end
			if rarityLabel then
				rarityLabel.Text = item.rarity or ""
				rarityLabel.TextColor3 = getRarityColor(item.rarity or "Common")
			end
			if valueLabel then
				valueLabel.Text = tostring(item.value or 0) .. " XP"
			end
			if border then
				border.Color = getRarityColor(item.rarity or "Common")
			end
		else
			if nameLabel then
				nameLabel.Text = "Empty"
				nameLabel.TextColor3 = style.TextSecondary
			end
			if rarityLabel then
				rarityLabel.Text = ""
			end
			if valueLabel then
				valueLabel.Text = ""
			end
			if border then
				border.Color = Color3.fromRGB(60, 60, 80)
			end
		end
	end
end

function InventoryClient.init()
	createInventoryUI()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	-- Toggle with Tab key
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Tab then
			isOpen = not isOpen
			if screenGui then
				screenGui.Enabled = isOpen
				if isOpen then
					refreshSlots()
				end
			end
		end
	end)

	-- Inventory updates from server
	remotes:WaitForChild(RemoteNames.InventoryUpdate).OnClientEvent:Connect(function(items)
		volatileItems = items or {}
		if isOpen then
			refreshSlots()
		end
	end)

	-- Close on round start
	remotes:WaitForChild(RemoteNames.RoundStateChanged).OnClientEvent:Connect(function(state)
		if state == "Active" then
			isOpen = false
			if screenGui then
				screenGui.Enabled = false
			end
		end
	end)
end

return InventoryClient
