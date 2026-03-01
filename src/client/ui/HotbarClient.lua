--[[
	HotbarClient — persistent 6-slot hotbar at the bottom of the screen.
	Always visible, even when inventory is closed.
	Shows first 6 items from player inventory.
	Number keys 1-6 to select a slot (visual highlight only for now).
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local HotbarClient = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Colours ──────────────────────────────────────────────
local BAR_BG = Color3.fromRGB(18, 18, 32)
local SLOT_EMPTY_BG = Color3.fromRGB(32, 32, 48)
local SLOT_EMPTY_BORDER = Color3.fromRGB(55, 55, 75)
local SLOT_SELECTED_BORDER = Color3.fromRGB(255, 210, 80)
local TEXT_WHITE = Color3.new(1, 1, 1)
local TEXT_GREY = Color3.fromRGB(110, 110, 130)
local TEXT_DIM = Color3.fromRGB(70, 70, 90)

local RARITY_COLORS = {
	Common = Color3.fromRGB(155, 155, 155),
	Uncommon = Color3.fromRGB(76, 175, 80),
	Rare = Color3.fromRGB(33, 150, 243),
	Epic = Color3.fromRGB(156, 39, 176),
	Legendary = Color3.fromRGB(255, 152, 0),
}

-- ── State ────────────────────────────────────────────────
local screenGui = nil
local barFrame = nil
local slots = {} -- array of Frame
local selectedSlot = 1
local cachedItems = {} -- items array mirroring player inventory

local SLOT_SIZE = 56
local SLOT_PAD = 5
local HOTBAR_SLOTS = Config.HOTBAR_SLOTS

-- ── Build ────────────────────────────────────────────────
local function buildHotbar()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HotbarUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local totalWidth = HOTBAR_SLOTS * SLOT_SIZE + (HOTBAR_SLOTS - 1) * SLOT_PAD + 24

	local bar = Instance.new("Frame")
	bar.Name = "HotbarFrame"
	bar.Size = UDim2.new(0, totalWidth, 0, SLOT_SIZE + 16)
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -8)
	bar.BackgroundColor3 = BAR_BG
	bar.BackgroundTransparency = 0.25
	bar.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bar

	local stroke = Instance.new("UIStroke")
	stroke.Color = SLOT_EMPTY_BORDER
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = bar

	-- Grid layout
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.Size = UDim2.new(1, -24, 0, SLOT_SIZE)
	grid.Position = UDim2.new(0, 12, 0.5, 0)
	grid.AnchorPoint = Vector2.new(0, 0.5)
	grid.BackgroundTransparency = 1
	grid.Parent = bar

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, SLOT_PAD)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	slots = {}
	for i = 1, HOTBAR_SLOTS do
		local slot = Instance.new("Frame")
		slot.Name = "HSlot_" .. i
		slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
		slot.LayoutOrder = i
		slot.BackgroundColor3 = SLOT_EMPTY_BG
		slot.BackgroundTransparency = 0.15
		slot.Parent = grid

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 5)
		slotCorner.Parent = slot

		local slotStroke = Instance.new("UIStroke")
		slotStroke.Name = "Border"
		slotStroke.Color = SLOT_EMPTY_BORDER
		slotStroke.Thickness = 1.5
		slotStroke.Parent = slot

		-- Number label (top-left)
		local numLabel = Instance.new("TextLabel")
		numLabel.Name = "NumKey"
		numLabel.Size = UDim2.new(0, 14, 0, 14)
		numLabel.Position = UDim2.new(0, 3, 0, 2)
		numLabel.BackgroundTransparency = 1
		numLabel.Text = tostring(i)
		numLabel.Font = Enum.Font.GothamBold
		numLabel.TextSize = 9
		numLabel.TextColor3 = TEXT_DIM
		numLabel.Parent = slot

		-- Item name (centred)
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "ItemName"
		nameLabel.Size = UDim2.new(1, -4, 0, 14)
		nameLabel.Position = UDim2.new(0, 2, 0.5, -4)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = ""
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 9
		nameLabel.TextColor3 = TEXT_WHITE
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = slot

		table.insert(slots, slot)
	end

	barFrame = bar
	screenGui = gui
end

local function refreshSlots()
	for i, slot in slots do
		local item = cachedItems[i]
		local nameLabel = slot:FindFirstChild("ItemName")
		local border = slot:FindFirstChild("Border")

		if item then
			local rarityColor = RARITY_COLORS[item.rarity] or RARITY_COLORS.Common

			if nameLabel then
				nameLabel.Text = item.name or "?"
				nameLabel.TextColor3 = TEXT_WHITE
			end
			if border then
				if i == selectedSlot then
					border.Color = SLOT_SELECTED_BORDER
					border.Thickness = 2.5
				else
					border.Color = rarityColor
					border.Thickness = 2
				end
			end
			slot.BackgroundColor3 = SLOT_EMPTY_BG
			slot.BackgroundTransparency = 0.08
		else
			if nameLabel then
				nameLabel.Text = ""
			end
			if border then
				if i == selectedSlot then
					border.Color = SLOT_SELECTED_BORDER
					border.Thickness = 2.5
				else
					border.Color = SLOT_EMPTY_BORDER
					border.Thickness = 1.5
				end
			end
			slot.BackgroundColor3 = SLOT_EMPTY_BG
			slot.BackgroundTransparency = 0.15
		end
	end
end

local function selectSlot(index: number)
	if index < 1 or index > HOTBAR_SLOTS then
		return
	end
	selectedSlot = index
	refreshSlots()
end

-- ── Public ───────────────────────────────────────────────

function HotbarClient.updateItems(items)
	cachedItems = items or {}
	refreshSlots()
end

function HotbarClient.init()
	buildHotbar()

	-- Number keys 1-6
	local numKeys = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.Five] = 5,
		[Enum.KeyCode.Six] = 6,
	}

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local slotNum = numKeys[input.KeyCode]
		if slotNum then
			selectSlot(slotNum)
		end
	end)

	-- Scroll wheel to cycle slots
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local dir = -input.Position.Z -- scroll up = prev, down = next
			local newSlot = selectedSlot + dir
			if newSlot < 1 then
				newSlot = HOTBAR_SLOTS
			elseif newSlot > HOTBAR_SLOTS then
				newSlot = 1
			end
			selectSlot(newSlot)
		end
	end)

	refreshSlots()
	print("[CAG] HotbarClient initialized (" .. HOTBAR_SLOTS .. " slots)")
end

return HotbarClient
