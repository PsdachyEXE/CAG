--[[
	InventoryClient — full-screen two-panel inventory UI.
	Left:  VICINITY (nearby ground items) — or CONTAINER when looting a crate.
	Right: PLAYER INVENTORY (16 slots, full screen height).

	Tab / I  = toggle.   Escape = close.
	Left-click LEFT panel  → pick up vicinity item / take from container.
	Left-click RIGHT panel → direct equip (fires directEquipCallback).
	Right-click RIGHT panel → context menu (EQUIP / DROP).
	Q while hovering RIGHT panel slot → drop item.
	Tooltip on hover after 0.5 s.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local InventoryClient = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Colours ──────────────────────────────────────────────
local OVERLAY_COLOR     = Color3.new(0, 0, 0)
local OVERLAY_ALPHA     = 0.60
local PANEL_BG          = Color3.fromRGB(22, 22, 36)
local PANEL_BORDER      = Color3.fromRGB(60, 60, 80)
local SLOT_EMPTY_BG     = Color3.fromRGB(35, 35, 50)
local SLOT_EMPTY_BORDER = Color3.fromRGB(65, 65, 85)
local SLOT_HOVER_BG     = Color3.fromRGB(50, 50, 70)
local TEXT_WHITE        = Color3.new(1, 1, 1)
local TEXT_GREY         = Color3.fromRGB(130, 130, 150)
local TEXT_DIM          = Color3.fromRGB(90, 90, 110)
local TOOLTIP_BG        = Color3.fromRGB(18, 18, 30)
local FULL_FLASH        = Color3.fromRGB(244, 67, 54)
local CONTEXT_BG        = Color3.fromRGB(13, 13, 18)
local CONTEXT_HOVER     = Color3.fromRGB(26, 26, 46)
local VICINITY_ACCENT   = Color3.fromRGB(80, 200, 120)
local CONTAINER_ACCENT  = Color3.fromRGB(220, 160, 60)

local RARITY_COLORS = {
	Common    = Color3.fromRGB(155, 155, 155),
	Uncommon  = Color3.fromRGB(76,  175, 80),
	Rare      = Color3.fromRGB(33,  150, 243),
	Epic      = Color3.fromRGB(156, 39,  176),
	Legendary = Color3.fromRGB(255, 152, 0),
}

-- ── Layout ────────────────────────────────────────────────
local SLOT_SIZE    = 72
local SLOT_PAD     = 6
local PANEL_PAD    = 16
local PANEL_MARGIN = 10
-- Panels use Scale sizing (each ~47.5% width) for full-screen coverage
local PANEL_WIDTH_SCALE = 0.475

-- ── State ─────────────────────────────────────────────────
local screenGui   = nil
local overlay     = nil
local leftPanel   = nil
local rightPanel  = nil
local tooltip     = nil
local contextMenu = nil

local isOpen          = false
local activeContainer = nil
local containerItems  = {}
local playerItems     = {}
local vicinityItems   = {}   -- { instance=Instance, itemData=table }

local hoverTimer            = 0
local hoveredSlot           = nil   -- { getItem, slot }
local tooltipVisible        = false
local hoveredInventoryIndex = nil   -- which right-panel slot index is under cursor

-- Callbacks
local hotbarUpdateCallback = nil
local equipCallback        = nil   -- legacy EQUIP flow
local directEquipCallback  = nil   -- left-click equip
local vicinityProvider     = nil   -- fn() → { {instance,itemData}, … }
local onOpenCallback       = nil
local onCloseCallback      = nil

-- Slot tables
local vicinitySlots  = {}
local inventorySlots = {}

-- forward declare
local refreshInventoryPanel

-- ── Toast ─────────────────────────────────────────────────
local toastGui    = nil
local activeToasts = {}

local function createToastGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ToastUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui
	toastGui = gui
end

local function showToast(text: string, color: Color3)
	if not toastGui then return end

	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(0, 240, 0, 36)
	toast.AnchorPoint = Vector2.new(1, 1)
	toast.Position = UDim2.new(1, -16, 1, -16 - (#activeToasts * 44))
	toast.BackgroundColor3 = PANEL_BG
	toast.BackgroundTransparency = 0.1
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

	local targetPos = toast.Position
	toast.Position = UDim2.new(1, 260, targetPos.Y.Scale, targetPos.Y.Offset)
	TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = targetPos,
	}):Play()
	table.insert(activeToasts, toast)

	task.spawn(function()
		task.wait(2.5)
		TweenService:Create(toast, TweenInfo.new(0.3), {
			Position = UDim2.new(1, 260, targetPos.Y.Scale, targetPos.Y.Offset),
			BackgroundTransparency = 1,
		}):Play()
		local lbl = toast:FindFirstChildOfClass("TextLabel")
		if lbl then TweenService:Create(lbl, TweenInfo.new(0.3), {TextTransparency = 1}):Play() end
		task.wait(0.3)
		for i, t in activeToasts do
			if t == toast then table.remove(activeToasts, i) break end
		end
		toast:Destroy()
		for i, t in activeToasts do
			TweenService:Create(t, TweenInfo.new(0.15), {
				Position = UDim2.new(1, -16, 1, -16 - ((i - 1) * 44)),
			}):Play()
		end
	end)
end

-- ── Tooltip ───────────────────────────────────────────────
local function createTooltip()
	local frame = Instance.new("Frame")
	frame.Name = "Tooltip"
	frame.Size = UDim2.new(0, 180, 0, 70)
	frame.BackgroundColor3 = TOOLTIP_BG
	frame.BackgroundTransparency = 0.05
	frame.Visible = false
	frame.ZIndex = 100
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Border"
	stroke.Color = SLOT_EMPTY_BORDER
	stroke.Thickness = 1
	stroke.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemName"
	nameLabel.Size = UDim2.new(1, -12, 0, 20)
	nameLabel.Position = UDim2.new(0, 6, 0, 6)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextColor3 = TEXT_WHITE
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = 101
	nameLabel.Parent = frame

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.Size = UDim2.new(1, -12, 0, 16)
	rarityLabel.Position = UDim2.new(0, 6, 0, 26)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextSize = 11
	rarityLabel.TextColor3 = TEXT_GREY
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
	rarityLabel.ZIndex = 101
	rarityLabel.Parent = frame

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.Size = UDim2.new(1, -12, 0, 16)
	valueLabel.Position = UDim2.new(0, 6, 0, 46)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Font = Enum.Font.Gotham
	valueLabel.TextSize = 11
	valueLabel.TextColor3 = TEXT_DIM
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.ZIndex = 101
	valueLabel.Parent = frame

	tooltip = frame
end

local function showTooltipForItem(item, position)
	if not tooltip or not item then return end
	local nameLabel   = tooltip:FindFirstChild("ItemName")
	local rarityLabel = tooltip:FindFirstChild("Rarity")
	local valueLabel  = tooltip:FindFirstChild("Value")
	local border      = tooltip:FindFirstChild("Border")
	local rarityColor = RARITY_COLORS[item.rarity] or RARITY_COLORS.Common
	if nameLabel   then nameLabel.Text   = item.name   or "Unknown"; nameLabel.TextColor3 = TEXT_WHITE end
	if rarityLabel then rarityLabel.Text = item.rarity or "";        rarityLabel.TextColor3 = rarityColor end
	if valueLabel  then valueLabel.Text  = "Value: " .. tostring(item.value or 0) end
	if border      then border.Color = rarityColor end
	tooltip.Position = UDim2.new(0, position.X + 12, 0, position.Y + 12)
	tooltip.Visible  = true
	tooltipVisible   = true
end

local function hideTooltip()
	if tooltip then tooltip.Visible = false end
	tooltipVisible        = false
	hoveredSlot           = nil
	hoveredInventoryIndex = nil
	hoverTimer            = 0
end

-- ── Context menu ──────────────────────────────────────────
local function hideContextMenu()
	if contextMenu then contextMenu.Visible = false end
end

local function showContextMenu(slotIndex: number, mousePos: Vector2)
	hideTooltip()
	hideContextMenu()
	if not contextMenu then return end
	local item = playerItems[slotIndex]
	if not item then return end
	contextMenu.Position = UDim2.new(0, mousePos.X + 4, 0, mousePos.Y)
	contextMenu.Visible  = true
	contextMenu:SetAttribute("TargetSlot", slotIndex)
end

local function createContextMenu()
	local menu = Instance.new("Frame")
	menu.Name = "ContextMenu"
	menu.Size = UDim2.new(0, 100, 0, 60)
	menu.BackgroundColor3 = CONTEXT_BG
	menu.BackgroundTransparency = 0.05
	menu.Visible = false
	menu.ZIndex = 120
	menu.Parent = screenGui

	Instance.new("UICorner").CornerRadius = UDim.new(0, 4)
	;(function()
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = menu
	end)()

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = menu

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = menu

	-- EQUIP
	local equipBtn = Instance.new("TextButton")
	equipBtn.Name = "EquipBtn"
	equipBtn.Size = UDim2.new(1, 0, 0, 30)
	equipBtn.LayoutOrder = 1
	equipBtn.BackgroundColor3 = CONTEXT_BG
	equipBtn.BackgroundTransparency = 0.05
	equipBtn.Text = "EQUIP"
	equipBtn.Font = Enum.Font.GothamBold
	equipBtn.TextSize = 13
	equipBtn.TextColor3 = TEXT_WHITE
	equipBtn.ZIndex = 121
	equipBtn.Parent = menu
	;(function()
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = equipBtn
	end)()
	equipBtn.MouseEnter:Connect(function() equipBtn.BackgroundColor3 = CONTEXT_HOVER end)
	equipBtn.MouseLeave:Connect(function() equipBtn.BackgroundColor3 = CONTEXT_BG end)
	equipBtn.MouseButton1Click:Connect(function()
		local slotIndex = menu:GetAttribute("TargetSlot")
		hideContextMenu()
		if slotIndex then
			if directEquipCallback then
				directEquipCallback(slotIndex, playerItems[slotIndex])
			elseif equipCallback then
				equipCallback(slotIndex)
			end
		end
	end)

	-- DROP
	local dropBtn = Instance.new("TextButton")
	dropBtn.Name = "DropBtn"
	dropBtn.Size = UDim2.new(1, 0, 0, 30)
	dropBtn.LayoutOrder = 2
	dropBtn.BackgroundColor3 = CONTEXT_BG
	dropBtn.BackgroundTransparency = 0.05
	dropBtn.Text = "DROP"
	dropBtn.Font = Enum.Font.GothamBold
	dropBtn.TextSize = 13
	dropBtn.TextColor3 = TEXT_WHITE
	dropBtn.ZIndex = 121
	dropBtn.Parent = menu
	;(function()
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = dropBtn
	end)()
	dropBtn.MouseEnter:Connect(function() dropBtn.BackgroundColor3 = CONTEXT_HOVER end)
	dropBtn.MouseLeave:Connect(function() dropBtn.BackgroundColor3 = CONTEXT_BG end)
	dropBtn.MouseButton1Click:Connect(function()
		local slotIndex = menu:GetAttribute("TargetSlot")
		hideContextMenu()
		if not slotIndex then return end

		local removedItem = playerItems[slotIndex]
		table.remove(playerItems, slotIndex)
		refreshInventoryPanel()

		local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
		if remotes then
			local dropRemote = remotes:FindFirstChild(RemoteNames.DropItem)
			if dropRemote then dropRemote:FireServer(slotIndex) end
		end
		if removedItem then
			showToast("- " .. removedItem.name, RARITY_COLORS[removedItem.rarity] or RARITY_COLORS.Common)
		end
	end)

	contextMenu = menu
end

-- ── Slot helpers ───────────────────────────────────────────
local function createSlot(parent, index: number, layoutOrder: number): Frame
	local slot = Instance.new("Frame")
	slot.Name = "Slot_" .. index
	slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	slot.LayoutOrder = layoutOrder
	slot.BackgroundColor3 = SLOT_EMPTY_BG
	slot.BackgroundTransparency = 0.15
	slot.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = slot

	local stroke = Instance.new("UIStroke")
	stroke.Name = "RarityBorder"
	stroke.Color = SLOT_EMPTY_BORDER
	stroke.Thickness = 1.5
	stroke.Parent = slot

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemName"
	nameLabel.Size = UDim2.new(1, -6, 0, 16)
	nameLabel.Position = UDim2.new(0, 3, 0.5, -14)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = ""
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 10
	nameLabel.TextColor3 = TEXT_WHITE
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = slot

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.Size = UDim2.new(1, -6, 0, 12)
	rarityLabel.Position = UDim2.new(0, 3, 0.5, 2)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = ""
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.TextSize = 9
	rarityLabel.TextColor3 = TEXT_GREY
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Center
	rarityLabel.Parent = slot

	return slot
end

local function updateSlot(slot: Frame, item)
	local nameLabel   = slot:FindFirstChild("ItemName")
	local rarityLabel = slot:FindFirstChild("Rarity")
	local border      = slot:FindFirstChild("RarityBorder")

	if item then
		local rarityColor = RARITY_COLORS[item.rarity] or RARITY_COLORS.Common
		if nameLabel   then nameLabel.Text   = item.name   or "?"; nameLabel.TextColor3 = TEXT_WHITE end
		if rarityLabel then rarityLabel.Text = item.rarity or "";  rarityLabel.TextColor3 = rarityColor end
		if border      then border.Color = rarityColor; border.Thickness = 2 end
		slot.BackgroundColor3 = SLOT_EMPTY_BG
		slot.BackgroundTransparency = 0.08
	else
		if nameLabel   then nameLabel.Text   = "" end
		if rarityLabel then rarityLabel.Text = "" end
		if border      then border.Color = SLOT_EMPTY_BORDER; border.Thickness = 1.5 end
		slot.BackgroundColor3 = SLOT_EMPTY_BG
		slot.BackgroundTransparency = 0.15
	end
end

local function flashInventoryFull()
	if not rightPanel then return end
	local border = rightPanel:FindFirstChild("PanelBorder")
	if border then
		border.Color = FULL_FLASH
		TweenService:Create(border, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = PANEL_BORDER,
		}):Play()
	end
	showToast("Inventory Full", FULL_FLASH)
end

-- ── Build panels ──────────────────────────────────────────
local function buildVicinityPanel(parent)
	local panel = Instance.new("Frame")
	panel.Name = "VicinityPanel"
	panel.Size = UDim2.new(PANEL_WIDTH_SCALE, 0, 1, -PANEL_MARGIN * 2)
	panel.Position = UDim2.new(-PANEL_WIDTH_SCALE - 0.02, 0, 0, PANEL_MARGIN)
	panel.BackgroundColor3 = PANEL_BG
	panel.BackgroundTransparency = 0.08
	panel.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Name = "PanelBorder"
	stroke.Color = VICINITY_ACCENT
	stroke.Thickness = 1.5
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -PANEL_PAD * 2, 0, 28)
	title.Position = UDim2.new(0, PANEL_PAD, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "VICINITY"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 16
	title.TextColor3 = VICINITY_ACCENT
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "SubLabel"
	subLabel.Size = UDim2.new(1, -PANEL_PAD * 2, 0, 14)
	subLabel.Position = UDim2.new(0, PANEL_PAD, 0, 38)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = "0 items nearby  •  click to pick up"
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 10
	subLabel.TextColor3 = TEXT_DIM
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.TextTruncate = Enum.TextTruncate.AtEnd
	subLabel.Parent = panel

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.Size = UDim2.new(1, -PANEL_PAD * 2, 1, -64)
	grid.Position = UDim2.new(0, PANEL_PAD, 0, 58)
	grid.BackgroundTransparency = 1
	grid.Parent = panel

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	layout.CellPadding = UDim2.new(0, SLOT_PAD, 0, SLOT_PAD)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	vicinitySlots = {}
	for i = 1, Config.MAX_INVENTORY_SLOTS do
		local slot = createSlot(grid, i, i)
		table.insert(vicinitySlots, slot)
	end

	leftPanel = panel
end

local function buildInventoryPanel(parent)
	local panel = Instance.new("Frame")
	panel.Name = "InventoryPanel"
	panel.Size = UDim2.new(PANEL_WIDTH_SCALE, 0, 1, -PANEL_MARGIN * 2)
	panel.Position = UDim2.new(1 + 0.02, 0, 0, PANEL_MARGIN)
	panel.BackgroundColor3 = PANEL_BG
	panel.BackgroundTransparency = 0.08
	panel.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Name = "PanelBorder"
	stroke.Color = PANEL_BORDER
	stroke.Thickness = 1.5
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -PANEL_PAD * 2, 0, 28)
	title.Position = UDim2.new(0, PANEL_PAD, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "INVENTORY"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 16
	title.TextColor3 = TEXT_WHITE
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "SlotCount"
	countLabel.Size = UDim2.new(1, -PANEL_PAD * 2, 0, 14)
	countLabel.Position = UDim2.new(0, PANEL_PAD, 0, 38)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = "0 / " .. Config.MAX_INVENTORY_SLOTS .. "  •  click=equip  Q=drop  RMB=menu"
	countLabel.Font = Enum.Font.Gotham
	countLabel.TextSize = 10
	countLabel.TextColor3 = TEXT_DIM
	countLabel.TextXAlignment = Enum.TextXAlignment.Left
	countLabel.TextTruncate = Enum.TextTruncate.AtEnd
	countLabel.Parent = panel

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.Size = UDim2.new(1, -PANEL_PAD * 2, 1, -64)
	grid.Position = UDim2.new(0, PANEL_PAD, 0, 58)
	grid.BackgroundTransparency = 1
	grid.Parent = panel

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	layout.CellPadding = UDim2.new(0, SLOT_PAD, 0, SLOT_PAD)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	inventorySlots = {}
	for i = 1, Config.MAX_INVENTORY_SLOTS do
		local slot = createSlot(grid, i, i)
		table.insert(inventorySlots, slot)
	end

	rightPanel = panel
end

-- ── Refresh ───────────────────────────────────────────────
local function refreshVicinityPanel()
	if not activeContainer then
		vicinityItems = vicinityProvider and vicinityProvider() or {}
	end

	for i, slot in vicinitySlots do
		local item = nil
		if activeContainer then
			item = containerItems[i]
		else
			local entry = vicinityItems[i]
			item = entry and entry.itemData or nil
		end
		updateSlot(slot, item)
	end

	if leftPanel then
		local title    = leftPanel:FindFirstChild("Title")
		local subLabel = leftPanel:FindFirstChild("SubLabel")
		local border   = leftPanel:FindFirstChild("PanelBorder")
		if activeContainer then
			if title    then title.Text    = "CONTAINER (" .. #containerItems .. ")"; title.TextColor3 = CONTAINER_ACCENT end
			if subLabel then subLabel.Text = "click an item to take it" end
			if border   then border.Color  = CONTAINER_ACCENT end
		else
			if title    then title.Text    = "VICINITY"; title.TextColor3 = VICINITY_ACCENT end
			local n = #vicinityItems
			if subLabel then subLabel.Text = n .. " item" .. (n == 1 and "" or "s") .. " nearby  •  click to pick up" end
			if border   then border.Color  = VICINITY_ACCENT end
		end
	end
end

refreshInventoryPanel = function()
	for i, slot in inventorySlots do
		updateSlot(slot, playerItems[i])
	end
	if rightPanel then
		local countLabel = rightPanel:FindFirstChild("SlotCount")
		if countLabel then
			countLabel.Text = #playerItems .. " / " .. Config.MAX_INVENTORY_SLOTS .. "  •  click=equip  Q=drop  RMB=menu"
		end
	end
	if hotbarUpdateCallback then
		hotbarUpdateCallback(playerItems)
	end
end

-- ── Slot interaction helper ────────────────────────────────
local function setupSlotInteraction(slot: Frame, getItem: () -> any?, onClick: (() -> ())?, onRightClick: (() -> ())?)
	local btn = Instance.new("TextButton")
	btn.Name = "ClickArea"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.ZIndex = 10
	btn.Parent = slot

	btn.MouseButton1Click:Connect(function()
		hideContextMenu()
		if onClick then onClick() end
	end)
	if onRightClick then
		btn.MouseButton2Click:Connect(onRightClick)
	end

	btn.MouseEnter:Connect(function()
		hoveredSlot = { getItem = getItem, slot = slot }
		hoverTimer = 0
		if getItem() then slot.BackgroundColor3 = SLOT_HOVER_BG end
	end)
	btn.MouseLeave:Connect(function()
		if hoveredSlot and hoveredSlot.slot == slot then
			hoveredSlot = nil
			hoverTimer  = 0
		end
		hideTooltip()
		local item = getItem()
		slot.BackgroundColor3 = SLOT_EMPTY_BG
		slot.BackgroundTransparency = item and 0.08 or 0.15
	end)
end

-- ── Drop by index ─────────────────────────────────────────
local function dropInventoryItem(index: number)
	local item = playerItems[index]
	if not item then return end
	table.remove(playerItems, index)
	if hoveredInventoryIndex == index then
		hoveredInventoryIndex = nil
		hoveredSlot           = nil
	end
	refreshInventoryPanel()

	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remotes then
		local dropRemote = remotes:FindFirstChild(RemoteNames.DropItem)
		if dropRemote then dropRemote:FireServer(index) end
	end
	showToast("- " .. (item.name or "Item"), RARITY_COLORS[item.rarity] or RARITY_COLORS.Common)
end

-- ── Build UI ──────────────────────────────────────────────
local function buildUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = playerGui

	-- Full-screen overlay
	local ov = Instance.new("Frame")
	ov.Name = "Overlay"
	ov.Size = UDim2.new(1, 0, 1, 0)
	ov.BackgroundColor3 = OVERLAY_COLOR
	ov.BackgroundTransparency = 1
	ov.ZIndex = 1
	ov.Parent = gui
	overlay = ov

	-- Keyboard hint at bottom centre
	local hint = Instance.new("TextLabel")
	hint.Name = "ControlsHint"
	hint.Size = UDim2.new(0, 380, 0, 20)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -14)
	hint.BackgroundTransparency = 1
	hint.Text = "TAB / I — open/close   •   Q — drop hovered item   •   ESC — close"
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 11
	hint.TextColor3 = TEXT_DIM
	hint.ZIndex = 3
	hint.Parent = gui

	-- Full-screen panel container
	local panelContainer = Instance.new("Frame")
	panelContainer.Name = "Panels"
	panelContainer.Size = UDim2.new(1, 0, 1, 0)
	panelContainer.BackgroundTransparency = 1
	panelContainer.ZIndex = 2
	panelContainer.Parent = gui

	buildVicinityPanel(panelContainer)
	buildInventoryPanel(panelContainer)

	createTooltip()
	createContextMenu()

	screenGui = gui

	-- ── Vicinity slot interactions ────────────────────────
	for i, slot in vicinitySlots do
		local idx = i
		setupSlotInteraction(slot,
			function()
				if activeContainer then
					return containerItems[idx]
				else
					local e = vicinityItems[idx]
					return e and e.itemData or nil
				end
			end,
			function()
				-- Left click: take from container or pick up from vicinity
				if activeContainer then
					if idx < 1 or idx > #containerItems then return end
					local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
					if not remotes then return end
					local takeRemote = remotes:FindFirstChild(RemoteNames.ContainerTakeItem)
					if takeRemote then
						takeRemote:FireServer(activeContainer, idx)
					end
				else
					local entry = vicinityItems[idx]
					if not entry or not entry.instance then return end
					local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
					if not remotes then return end
					local pickupRemote = remotes:FindFirstChild(RemoteNames.PickupItem)
					if pickupRemote then
						pickupRemote:FireServer(entry.instance)
						table.remove(vicinityItems, idx)
						refreshVicinityPanel()
					end
				end
			end,
			nil
		)
	end

	-- ── Inventory slot interactions ───────────────────────
	for i, slot in inventorySlots do
		local idx = i
		setupSlotInteraction(slot,
			function() return playerItems[idx] end,
			function()
				-- Left click: direct equip
				local item = playerItems[idx]
				if item then
					if directEquipCallback then
						directEquipCallback(idx, item)
					elseif equipCallback then
						equipCallback(idx)
					end
				end
			end,
			function()
				-- Right click: context menu
				local item = playerItems[idx]
				if item then
					hoveredInventoryIndex = idx
					local mousePos = UserInputService:GetMouseLocation()
					showContextMenu(idx, mousePos)
				end
			end
		)

		-- Track hover index for Q-drop (supplemental to the generic setup above)
		local btn = slot:FindFirstChild("ClickArea")
		if btn then
			btn.MouseEnter:Connect(function() hoveredInventoryIndex = idx end)
			btn.MouseLeave:Connect(function()
				if hoveredInventoryIndex == idx then hoveredInventoryIndex = nil end
			end)
		end
	end
end

-- ── Animation constants ───────────────────────────────────
local ANIM_T  = 0.22
local STAGGER = 0.05

-- Scale-based positions for full-screen panels
local LEFT_OPEN   = UDim2.new(0.0125, 0, 0, PANEL_MARGIN)
local LEFT_CLOSE  = UDim2.new(-PANEL_WIDTH_SCALE - 0.02, 0, 0, PANEL_MARGIN)
local RIGHT_OPEN  = UDim2.new(1 - PANEL_WIDTH_SCALE - 0.0125, 0, 0, PANEL_MARGIN)
local RIGHT_CLOSE = UDim2.new(1 + 0.02, 0, 0, PANEL_MARGIN)

-- ── Open / Close ──────────────────────────────────────────
local function openUI(withContainer: boolean)
	if isOpen then return end
	isOpen = true
	if not screenGui then return end
	screenGui.Enabled = true

	if onOpenCallback then onOpenCallback() end

	overlay.BackgroundTransparency = 1
	TweenService:Create(overlay, TweenInfo.new(ANIM_T), {
		BackgroundTransparency = OVERLAY_ALPHA,
	}):Play()

	-- Left panel slides in from left edge
	leftPanel.Visible  = true
	leftPanel.Position = LEFT_CLOSE
	task.spawn(function()
		task.wait(STAGGER)
		TweenService:Create(leftPanel, TweenInfo.new(ANIM_T, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = LEFT_OPEN,
		}):Play()
	end)

	-- Right panel slides in from right edge
	rightPanel.Position = RIGHT_CLOSE
	task.spawn(function()
		task.wait(STAGGER * 2)
		TweenService:Create(rightPanel, TweenInfo.new(ANIM_T, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = RIGHT_OPEN,
		}):Play()
	end)

	refreshVicinityPanel()
	refreshInventoryPanel()
end

local function closeUI()
	if not isOpen then return end
	isOpen = false
	activeContainer = nil
	hideTooltip()
	hideContextMenu()

	if onCloseCallback then onCloseCallback() end

	local half = ANIM_T * 0.75
	TweenService:Create(overlay, TweenInfo.new(half), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(leftPanel,  TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = LEFT_CLOSE  }):Play()
	TweenService:Create(rightPanel, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = RIGHT_CLOSE }):Play()

	task.spawn(function()
		task.wait(half + 0.05)
		if not isOpen then screenGui.Enabled = false end
	end)
end

-- ── Public API ────────────────────────────────────────────
function InventoryClient.openWithContainer(data)
	activeContainer = data.container
	containerItems  = data.containerItems or {}
	playerItems     = data.playerItems    or {}
	openUI(true)
end

function InventoryClient.toggleInventory()
	if isOpen then
		closeUI()
	else
		containerItems  = {}
		activeContainer = nil
		openUI(false)
	end
end

function InventoryClient.isOpen()          return isOpen      end
function InventoryClient.close()           closeUI()          end
function InventoryClient.getPlayerItems()  return playerItems end

-- Setters
function InventoryClient.setHotbarCallback(fn)     hotbarUpdateCallback = fn end
function InventoryClient.setEquipCallback(fn)       equipCallback        = fn end
function InventoryClient.setDirectEquipCallback(fn) directEquipCallback  = fn end
function InventoryClient.setVicinityProvider(fn)    vicinityProvider     = fn end
function InventoryClient.setOnOpenCallback(fn)      onOpenCallback       = fn end
function InventoryClient.setOnCloseCallback(fn)     onCloseCallback      = fn end

-- ── Init ──────────────────────────────────────────────────
function InventoryClient.init()
	buildUI()
	createToastGui()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)

	-- ── Input ─────────────────────────────────────────────
	UserInputService.InputBegan:Connect(function(input, processed)
		-- Toggle: Tab or I (allow even if processed so Tab doesn't open system menu)
		if input.KeyCode == Enum.KeyCode.Tab or input.KeyCode == Enum.KeyCode.I then
			InventoryClient.toggleInventory()
			return
		end
		if processed then return end

		-- Escape: close
		if input.KeyCode == Enum.KeyCode.Escape and isOpen then
			closeUI()
			return
		end

		-- Q: drop hovered inventory item
		if input.KeyCode == Enum.KeyCode.Q and isOpen and hoveredInventoryIndex then
			dropInventoryItem(hoveredInventoryIndex)
		end
	end)

	-- ── Remote listeners ──────────────────────────────────

	-- Server sends container + player inventory on E interact
	remotes:WaitForChild(RemoteNames.InventoryState).OnClientEvent:Connect(function(data)
		if data then InventoryClient.openWithContainer(data) end
	end)

	-- Server confirms an item was taken from container
	remotes:WaitForChild(RemoteNames.ItemTransferred).OnClientEvent:Connect(function(data)
		if not data then return end
		containerItems = data.containerItems or {}
		playerItems    = data.playerItems    or {}
		if isOpen then
			refreshVicinityPanel()
			refreshInventoryPanel()
		end
		if data.takenItem then
			local item = data.takenItem
			showToast("+ " .. item.name, RARITY_COLORS[item.rarity] or RARITY_COLORS.Common)
		end
		-- Auto-switch vicinity panel when container empties
		if activeContainer and #containerItems == 0 then
			task.spawn(function()
				task.wait(0.3)
				if isOpen and #containerItems == 0 then
					activeContainer = nil
					refreshVicinityPanel()
				end
			end)
		end
	end)

	-- Ground item picked up: add to local inventory
	remotes:WaitForChild(RemoteNames.ItemPickedUp).OnClientEvent:Connect(function(itemData)
		if not itemData then return end
		table.insert(playerItems, itemData)
		if isOpen then
			refreshInventoryPanel()
		else
			if hotbarUpdateCallback then hotbarUpdateCallback(playerItems) end
		end
		showToast("+ " .. (itemData.name or "Item"), RARITY_COLORS[itemData.rarity] or RARITY_COLORS.Common)
	end)

	-- A ground item disappeared: refresh vicinity so stale slots clear
	remotes:WaitForChild(RemoteNames.GroundItemRemoved).OnClientEvent:Connect(function(_instance)
		if isOpen and not activeContainer then
			refreshVicinityPanel()
		end
	end)

	remotes:WaitForChild(RemoteNames.InteractFailed).OnClientEvent:Connect(function(reason)
		if reason == "INVENTORY_FULL" then flashInventoryFull() end
	end)

	remotes:WaitForChild(RemoteNames.PickupFailed).OnClientEvent:Connect(function(reason)
		if reason == "INVENTORY_FULL" then flashInventoryFull() end
	end)

	-- Tooltip hover timer
	RunService.Heartbeat:Connect(function(dt)
		if not hoveredSlot then return end
		hoverTimer = hoverTimer + dt
		if hoverTimer >= Config.TOOLTIP_HOVER_DELAY and not tooltipVisible then
			local item = hoveredSlot.getItem()
			if item then
				showTooltipForItem(item, UserInputService:GetMouseLocation())
			end
		end
		if tooltipVisible then
			tooltip.Position = UDim2.new(0, UserInputService:GetMouseLocation().X + 12, 0, UserInputService:GetMouseLocation().Y + 12)
		end
	end)

	print("[CAG] InventoryClient initialized (full-screen, vicinity panel, Q-drop, left-click equip)")
end

return InventoryClient
