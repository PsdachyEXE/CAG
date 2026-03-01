--[[
	InventoryClient — DayZ-style three-panel inventory UI.
	Left:   Container contents (4col x 2row = 8 slots)
	Centre: Character viewport (R6 noob rig) + HANDS slot + hotbar preview
	Right:  Player inventory (4col x 4row = 16 slots)

	Tab / Escape to toggle. Also opens on container interact (InventoryState).
	Click container item → fires ContainerTakeItem → server transfers it.
	Tooltip on hover after 0.5s delay.
]]

local Players = game:GetService("Players")
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
local OVERLAY_COLOR = Color3.new(0, 0, 0)
local OVERLAY_TRANSPARENCY = 0.55 -- 45% opacity
local PANEL_BG = Color3.fromRGB(22, 22, 36)
local PANEL_BORDER = Color3.fromRGB(60, 60, 80)
local SLOT_EMPTY_BG = Color3.fromRGB(35, 35, 50)
local SLOT_EMPTY_BORDER = Color3.fromRGB(65, 65, 85)
local SLOT_HOVER_BG = Color3.fromRGB(50, 50, 70)
local TEXT_WHITE = Color3.new(1, 1, 1)
local TEXT_GREY = Color3.fromRGB(130, 130, 150)
local TEXT_DIM = Color3.fromRGB(90, 90, 110)
local HANDS_BG = Color3.fromRGB(45, 45, 65)
local TOOLTIP_BG = Color3.fromRGB(18, 18, 30)
local FULL_FLASH = Color3.fromRGB(244, 67, 54)

local RARITY_COLORS = {
	Common = Color3.fromRGB(155, 155, 155),
	Uncommon = Color3.fromRGB(76, 175, 80),
	Rare = Color3.fromRGB(33, 150, 243),
	Epic = Color3.fromRGB(156, 39, 176),
	Legendary = Color3.fromRGB(255, 152, 0),
}

-- ── State ────────────────────────────────────────────────
local screenGui = nil
local overlay = nil
local leftPanel = nil   -- container panel
local centrePanel = nil  -- character + hands
local rightPanel = nil   -- player inventory
local tooltip = nil

local isOpen = false
local activeContainer = nil  -- Instance reference of the open container
local containerItems = {}    -- array from server
local playerItems = {}       -- array from server

local hoverTimer = 0
local hoveredSlot = nil
local tooltipVisible = false

-- Callbacks for hotbar updates
local hotbarUpdateCallback = nil

-- ── Slot dimensions ──────────────────────────────────────
local SLOT_SIZE = 64
local SLOT_PAD = 6
local PANEL_PAD = 16

-- ── Toast system ─────────────────────────────────────────
local toastGui = nil
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
	if not toastGui then
		return
	end

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

	-- Slide in from right
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
		if lbl then
			TweenService:Create(lbl, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		end

		task.wait(0.3)
		for i, t in activeToasts do
			if t == toast then
				table.remove(activeToasts, i)
				break
			end
		end
		toast:Destroy()

		for i, t in activeToasts do
			local yOff = -16 - ((i - 1) * 44)
			TweenService:Create(t, TweenInfo.new(0.15), {
				Position = UDim2.new(1, -16, 1, yOff),
			}):Play()
		end
	end)
end

-- ── Tooltip ──────────────────────────────────────────────
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
	if not tooltip or not item then
		return
	end

	local nameLabel = tooltip:FindFirstChild("ItemName")
	local rarityLabel = tooltip:FindFirstChild("Rarity")
	local valueLabel = tooltip:FindFirstChild("Value")
	local border = tooltip:FindFirstChild("Border")

	local rarityColor = RARITY_COLORS[item.rarity] or RARITY_COLORS.Common

	if nameLabel then
		nameLabel.Text = item.name or "Unknown"
		nameLabel.TextColor3 = TEXT_WHITE
	end
	if rarityLabel then
		rarityLabel.Text = item.rarity or ""
		rarityLabel.TextColor3 = rarityColor
	end
	if valueLabel then
		valueLabel.Text = "Value: " .. tostring(item.value or 0)
	end
	if border then
		border.Color = rarityColor
	end

	-- Position tooltip near mouse, offset right+down
	tooltip.Position = UDim2.new(0, position.X + 12, 0, position.Y + 12)
	tooltip.Visible = true
	tooltipVisible = true
end

local function hideTooltip()
	if tooltip then
		tooltip.Visible = false
	end
	tooltipVisible = false
	hoveredSlot = nil
	hoverTimer = 0
end

-- ── Slot creation helpers ────────────────────────────────
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

	-- Item name label (centred)
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

	-- Rarity label below name
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
	local nameLabel = slot:FindFirstChild("ItemName")
	local rarityLabel = slot:FindFirstChild("Rarity")
	local border = slot:FindFirstChild("RarityBorder")

	if item then
		local rarityColor = RARITY_COLORS[item.rarity] or RARITY_COLORS.Common
		if nameLabel then
			nameLabel.Text = item.name or "?"
			nameLabel.TextColor3 = TEXT_WHITE
		end
		if rarityLabel then
			rarityLabel.Text = item.rarity or ""
			rarityLabel.TextColor3 = rarityColor
		end
		if border then
			border.Color = rarityColor
			border.Thickness = 2
		end
		slot.BackgroundColor3 = SLOT_EMPTY_BG
		slot.BackgroundTransparency = 0.08
	else
		if nameLabel then
			nameLabel.Text = ""
		end
		if rarityLabel then
			rarityLabel.Text = ""
		end
		if border then
			border.Color = SLOT_EMPTY_BORDER
			border.Thickness = 1.5
		end
		slot.BackgroundColor3 = SLOT_EMPTY_BG
		slot.BackgroundTransparency = 0.15
	end
end

-- ── Inventory full flash ─────────────────────────────────
local function flashInventoryFull()
	if not rightPanel then
		return
	end

	local border = rightPanel:FindFirstChild("PanelBorder")
	if border then
		border.Color = FULL_FLASH
		TweenService:Create(border, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = PANEL_BORDER,
		}):Play()
	end

	showToast("Inventory Full", FULL_FLASH)
end

-- ── Build panels ─────────────────────────────────────────

local containerSlots = {} -- array of slot Frames
local inventorySlots = {} -- array of slot Frames

local function buildContainerPanel(parent)
	local panel = Instance.new("Frame")
	panel.Name = "ContainerPanel"
	panel.Size = UDim2.new(0, 4 * SLOT_SIZE + 3 * SLOT_PAD + 2 * PANEL_PAD, 1, 0)
	panel.Position = UDim2.new(0, -400, 0, 0) -- start off-screen left
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

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.new(0, 0, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "CONTAINER"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 16
	title.TextColor3 = TEXT_WHITE
	title.Parent = panel

	-- Grid
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.Size = UDim2.new(1, -2 * PANEL_PAD, 0, 2 * SLOT_SIZE + SLOT_PAD)
	grid.Position = UDim2.new(0, PANEL_PAD, 0, 50)
	grid.BackgroundTransparency = 1
	grid.Parent = panel

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	layout.CellPadding = UDim2.new(0, SLOT_PAD, 0, SLOT_PAD)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	-- 8 slots (4x2)
	containerSlots = {}
	for i = 1, 8 do
		local slot = createSlot(grid, i, i)
		table.insert(containerSlots, slot)
	end

	leftPanel = panel
end

local function buildCentrePanel(parent)
	local panelWidth = 200
	local panel = Instance.new("Frame")
	panel.Name = "CentrePanel"
	panel.Size = UDim2.new(0, panelWidth, 1, 0)
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 0)
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

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.new(0, 0, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "CHARACTER"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 16
	title.TextColor3 = TEXT_WHITE
	title.Parent = panel

	-- ViewportFrame for character model
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "CharViewport"
	viewport.Size = UDim2.new(0, 140, 0, 200)
	viewport.AnchorPoint = Vector2.new(0.5, 0)
	viewport.Position = UDim2.new(0.5, 0, 0, 46)
	viewport.BackgroundColor3 = Color3.fromRGB(28, 28, 44)
	viewport.BackgroundTransparency = 0.3
	viewport.Parent = panel

	local vpCorner = Instance.new("UICorner")
	vpCorner.CornerRadius = UDim.new(0, 6)
	vpCorner.Parent = viewport

	-- Build R6 noob character in viewport
	task.spawn(function()
		local char = player.Character or player.CharacterAdded:Wait()
		if char then
			local clone = char:Clone()
			-- Remove scripts and non-visual
			for _, child in clone:GetDescendants() do
				if child:IsA("BaseScript") or child:IsA("Sound") then
					child:Destroy()
				end
			end
			clone.Parent = viewport

			-- Camera for viewport
			local cam = Instance.new("Camera")
			cam.CFrame = CFrame.new(Vector3.new(0, 2.5, 6), Vector3.new(0, 2.5, 0))
			cam.Parent = viewport
			viewport.CurrentCamera = cam

			-- Position model at origin
			local hrp = clone:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.CFrame = CFrame.new(0, 0, 0)
			end
		end
	end)

	-- HANDS slot
	local handsFrame = Instance.new("Frame")
	handsFrame.Name = "HandsSlot"
	handsFrame.Size = UDim2.new(0, 100, 0, 40)
	handsFrame.AnchorPoint = Vector2.new(0.5, 0)
	handsFrame.Position = UDim2.new(0.5, 0, 0, 260)
	handsFrame.BackgroundColor3 = HANDS_BG
	handsFrame.BackgroundTransparency = 0.15
	handsFrame.Parent = panel

	local handsCorner = Instance.new("UICorner")
	handsCorner.CornerRadius = UDim.new(0, 5)
	handsCorner.Parent = handsFrame

	local handsStroke = Instance.new("UIStroke")
	handsStroke.Color = SLOT_EMPTY_BORDER
	handsStroke.Thickness = 1.5
	handsStroke.Parent = handsFrame

	local handsLabel = Instance.new("TextLabel")
	handsLabel.Size = UDim2.new(1, 0, 1, 0)
	handsLabel.BackgroundTransparency = 1
	handsLabel.Text = "HANDS"
	handsLabel.Font = Enum.Font.GothamBold
	handsLabel.TextSize = 12
	handsLabel.TextColor3 = TEXT_DIM
	handsLabel.Parent = handsFrame

	centrePanel = panel
end

local function buildInventoryPanel(parent)
	local panel = Instance.new("Frame")
	panel.Name = "InventoryPanel"
	panel.Size = UDim2.new(0, 4 * SLOT_SIZE + 3 * SLOT_PAD + 2 * PANEL_PAD, 1, 0)
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, 400, 0, 0) -- start off-screen right
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

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.new(0, 0, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "INVENTORY"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 16
	title.TextColor3 = TEXT_WHITE
	title.Parent = panel

	-- Slot count
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "SlotCount"
	countLabel.Size = UDim2.new(1, -16, 0, 14)
	countLabel.Position = UDim2.new(0, 8, 0, 36)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = "0 / " .. Config.MAX_INVENTORY_SLOTS
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextSize = 10
	countLabel.TextColor3 = TEXT_DIM
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.Parent = panel

	-- Grid
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.Size = UDim2.new(1, -2 * PANEL_PAD, 0, 4 * SLOT_SIZE + 3 * SLOT_PAD)
	grid.Position = UDim2.new(0, PANEL_PAD, 0, 56)
	grid.BackgroundTransparency = 1
	grid.Parent = panel

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	layout.CellPadding = UDim2.new(0, SLOT_PAD, 0, SLOT_PAD)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	-- 16 slots (4x4)
	inventorySlots = {}
	for i = 1, Config.MAX_INVENTORY_SLOTS do
		local slot = createSlot(grid, i, i)
		table.insert(inventorySlots, slot)
	end

	rightPanel = panel
end

-- ── Refresh panels ───────────────────────────────────────
local function refreshContainerPanel()
	for i, slot in containerSlots do
		local item = containerItems[i]
		updateSlot(slot, item)
	end

	-- Update title to show count
	if leftPanel then
		local title = leftPanel:FindFirstChild("Title")
		if title then
			local count = 0
			for _ in containerItems do
				count = count + 1
			end
			title.Text = "CONTAINER (" .. #containerItems .. ")"
		end
	end
end

local function refreshInventoryPanel()
	for i, slot in inventorySlots do
		local item = playerItems[i]
		updateSlot(slot, item)
	end

	-- Update slot count
	if rightPanel then
		local countLabel = rightPanel:FindFirstChild("SlotCount")
		if countLabel then
			countLabel.Text = #playerItems .. " / " .. Config.MAX_INVENTORY_SLOTS
		end
	end

	-- Notify hotbar
	if hotbarUpdateCallback then
		hotbarUpdateCallback(playerItems)
	end
end

-- ── Container slot click handler ─────────────────────────
local function onContainerSlotClick(index: number)
	if not activeContainer then
		return
	end
	if index < 1 or index > #containerItems then
		return
	end

	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remotes then
		return
	end
	local takeRemote = remotes:FindFirstChild(RemoteNames.ContainerTakeItem)
	if not takeRemote then
		return
	end

	takeRemote:FireServer(activeContainer, index)
end

-- ── Hover handler for slots ──────────────────────────────
local function setupSlotInteraction(slot: Frame, getItem: () -> any?, onClick: (() -> ())?)
	-- Click
	local btn = Instance.new("TextButton")
	btn.Name = "ClickArea"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.ZIndex = 10
	btn.Parent = slot

	if onClick then
		btn.MouseButton1Click:Connect(function()
			onClick()
		end)
	end

	-- Hover enter
	btn.MouseEnter:Connect(function()
		hoveredSlot = { getItem = getItem, slot = slot }
		hoverTimer = 0

		-- Subtle highlight
		local item = getItem()
		if item then
			slot.BackgroundColor3 = SLOT_HOVER_BG
		end
	end)

	-- Hover leave
	btn.MouseLeave:Connect(function()
		if hoveredSlot and hoveredSlot.slot == slot then
			hoveredSlot = nil
			hoverTimer = 0
		end
		hideTooltip()

		local item = getItem()
		if item then
			slot.BackgroundColor3 = SLOT_EMPTY_BG
			slot.BackgroundTransparency = 0.08
		else
			slot.BackgroundColor3 = SLOT_EMPTY_BG
			slot.BackgroundTransparency = 0.15
		end
	end)
end

-- ── Build full UI ────────────────────────────────────────
local function buildUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = playerGui

	-- Fullscreen overlay
	local ov = Instance.new("Frame")
	ov.Name = "Overlay"
	ov.Size = UDim2.new(1, 0, 1, 0)
	ov.BackgroundColor3 = OVERLAY_COLOR
	ov.BackgroundTransparency = 1 -- start transparent
	ov.ZIndex = 1
	ov.Parent = gui
	overlay = ov

	-- Panel container (centred, holds all 3 panels)
	local panelContainer = Instance.new("Frame")
	panelContainer.Name = "Panels"
	panelContainer.Size = UDim2.new(0.9, 0, 0, 400)
	panelContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	panelContainer.Position = UDim2.new(0.5, 0, 0.45, 0)
	panelContainer.BackgroundTransparency = 1
	panelContainer.ZIndex = 2
	panelContainer.Parent = gui

	-- Build three panels
	buildContainerPanel(panelContainer)
	buildCentrePanel(panelContainer)
	buildInventoryPanel(panelContainer)

	-- Create tooltip
	createTooltip()
	if tooltip then
		tooltip.ZIndex = 100
	end

	screenGui = gui

	-- Setup slot interactions for container slots
	for i, slot in containerSlots do
		setupSlotInteraction(slot, function()
			return containerItems[i]
		end, function()
			onContainerSlotClick(i)
		end)
	end

	-- Setup slot interactions for inventory slots (no click action for now)
	for i, slot in inventorySlots do
		setupSlotInteraction(slot, function()
			return playerItems[i]
		end, nil)
	end
end

-- ── Open / Close animations ──────────────────────────────
local ANIM_TIME = 0.25
local STAGGER = 0.06

local function openUI(withContainer: boolean)
	if isOpen then
		return
	end
	isOpen = true

	if not screenGui then
		return
	end
	screenGui.Enabled = true

	-- Fade in overlay
	overlay.BackgroundTransparency = 1
	TweenService:Create(overlay, TweenInfo.new(ANIM_TIME), {
		BackgroundTransparency = OVERLAY_TRANSPARENCY,
	}):Play()

	-- Centre panel slides in first (from below)
	centrePanel.Position = UDim2.new(0.5, 0, 0, 60)
	TweenService:Create(centrePanel, TweenInfo.new(ANIM_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 0),
	}):Play()

	-- Right panel slides in from right (stagger)
	rightPanel.Position = UDim2.new(1, 400, 0, 0)
	task.spawn(function()
		task.wait(STAGGER)
		TweenService:Create(rightPanel, TweenInfo.new(ANIM_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(1, 0, 0, 0),
		}):Play()
	end)

	-- Left panel only shows if we have a container
	if withContainer and leftPanel then
		leftPanel.Visible = true
		leftPanel.Position = UDim2.new(0, -400, 0, 0)
		task.spawn(function()
			task.wait(STAGGER)
			TweenService:Create(leftPanel, TweenInfo.new(ANIM_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, 0, 0, 0),
			}):Play()
		end)
	else
		if leftPanel then
			leftPanel.Visible = false
		end
	end

	refreshContainerPanel()
	refreshInventoryPanel()
end

local function closeUI()
	if not isOpen then
		return
	end
	isOpen = false
	activeContainer = nil
	hideTooltip()

	-- Fade out overlay
	TweenService:Create(overlay, TweenInfo.new(ANIM_TIME * 0.75), {
		BackgroundTransparency = 1,
	}):Play()

	-- Slide panels out
	TweenService:Create(centrePanel, TweenInfo.new(ANIM_TIME * 0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, 0, 60),
	}):Play()

	TweenService:Create(rightPanel, TweenInfo.new(ANIM_TIME * 0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(1, 400, 0, 0),
	}):Play()

	if leftPanel and leftPanel.Visible then
		TweenService:Create(leftPanel, TweenInfo.new(ANIM_TIME * 0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0, -400, 0, 0),
		}):Play()
	end

	task.spawn(function()
		task.wait(ANIM_TIME)
		if not isOpen then
			screenGui.Enabled = false
		end
	end)
end

-- ── Public API ───────────────────────────────────────────

-- Called by InteractClient when server sends InventoryState
function InventoryClient.openWithContainer(data)
	activeContainer = data.container
	containerItems = data.containerItems or {}
	playerItems = data.playerItems or {}
	openUI(true)
end

-- Tab toggle (no container)
function InventoryClient.toggleInventory()
	if isOpen then
		closeUI()
	else
		-- Open without container panel
		containerItems = {}
		activeContainer = nil
		openUI(false)
	end
end

function InventoryClient.isOpen()
	return isOpen
end

function InventoryClient.close()
	closeUI()
end

function InventoryClient.setHotbarCallback(callback)
	hotbarUpdateCallback = callback
end

function InventoryClient.getPlayerItems()
	return playerItems
end

function InventoryClient.init()
	buildUI()
	createToastGui()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	-- Tab key toggle / Escape close
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Tab then
			InventoryClient.toggleInventory()
		elseif input.KeyCode == Enum.KeyCode.Escape then
			if isOpen then
				closeUI()
			end
		end
	end)

	-- InventoryState — server sends container+player contents on interact
	remotes:WaitForChild(RemoteNames.InventoryState).OnClientEvent:Connect(function(data)
		if data then
			InventoryClient.openWithContainer(data)
		end
	end)

	-- ItemTransferred — server confirms an item was taken
	remotes:WaitForChild(RemoteNames.ItemTransferred).OnClientEvent:Connect(function(data)
		if data then
			containerItems = data.containerItems or {}
			playerItems = data.playerItems or {}

			if isOpen then
				refreshContainerPanel()
				refreshInventoryPanel()
			end

			-- Toast for taken item
			if data.takenItem then
				local item = data.takenItem
				local rarityColor = RARITY_COLORS[item.rarity] or RARITY_COLORS.Common
				showToast("+ " .. item.name, rarityColor)
			end

			-- If container now empty, hide container panel
			if #containerItems == 0 and leftPanel then
				task.spawn(function()
					task.wait(0.3)
					if isOpen and #containerItems == 0 then
						TweenService:Create(leftPanel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
							Position = UDim2.new(0, -400, 0, 0),
						}):Play()
						task.wait(0.2)
						leftPanel.Visible = false
						activeContainer = nil
					end
				end)
			end
		end
	end)

	-- InteractFailed — red flash
	remotes:WaitForChild(RemoteNames.InteractFailed).OnClientEvent:Connect(function(reason)
		if reason == "INVENTORY_FULL" then
			flashInventoryFull()
		end
	end)

	-- Tooltip hover timer
	RunService.Heartbeat:Connect(function(dt)
		if hoveredSlot then
			hoverTimer = hoverTimer + dt
			if hoverTimer >= Config.TOOLTIP_HOVER_DELAY and not tooltipVisible then
				local item = hoveredSlot.getItem()
				if item then
					local mousePos = UserInputService:GetMouseLocation()
					showTooltipForItem(item, mousePos)
				end
			end
			-- Update tooltip position while visible
			if tooltipVisible then
				local mousePos = UserInputService:GetMouseLocation()
				tooltip.Position = UDim2.new(0, mousePos.X + 12, 0, mousePos.Y + 12)
			end
		end
	end)

	print("[CAG] InventoryClient initialized (3-panel DayZ-style)")
end

return InventoryClient
