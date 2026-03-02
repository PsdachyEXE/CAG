--[[
	HotbarClient — persistent 6-slot hotbar at screen bottom.
	Always visible. Slots 1-2: weapons only. Slots 3-6: any item.
	Number keys 1-6 to equip (fires EquipItem). Scroll wheel to cycle.
	G key to unequip. Supports equip assignment flow from InventoryClient.
	Shows emoji + name on assigned items.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local HotbarClient = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Colours ──────────────────────────────────────────────
local BAR_BG = Color3.fromRGB(18, 18, 32)
local SLOT_EMPTY_BG = Color3.fromRGB(32, 32, 48)
local SLOT_EMPTY_BORDER = Color3.fromRGB(55, 55, 75)
local SLOT_SELECTED_BORDER = Color3.fromRGB(255, 210, 80)
local SLOT_ACTIVE_BG = Color3.fromRGB(48, 48, 68)
local SLOT_PULSE_BORDER = Color3.new(1, 1, 1)
local TEXT_WHITE = Color3.new(1, 1, 1)
local TEXT_DIM = Color3.fromRGB(70, 70, 90)
local TOAST_BG = Color3.fromRGB(13, 13, 18)
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
local barFrame = nil
local equipToast = nil
local slots = {}
local equippedSlot = nil -- currently equipped (active) slot index
local hotbarItems = {}   -- [slotIndex] = itemData or nil

-- Assignment mode state
local isAssigning = false
local assigningInventoryIndex = nil
local assigningIsWeapon = false
local pulsingTweens = {}

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

		-- Slot type label (top-right, shows weapon restriction)
		if i <= 2 then
			local typeLabel = Instance.new("TextLabel")
			typeLabel.Name = "TypeLabel"
			typeLabel.Size = UDim2.new(0, 14, 0, 10)
			typeLabel.Position = UDim2.new(1, -16, 0, 2)
			typeLabel.BackgroundTransparency = 1
			typeLabel.Text = "\u{1F52B}"
			typeLabel.TextSize = 8
			typeLabel.Parent = slot
		end

		-- Icon label (centre-top, emoji)
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Name = "Icon"
		iconLabel.Size = UDim2.new(1, 0, 0, 20)
		iconLabel.Position = UDim2.new(0, 0, 0, 12)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = ""
		iconLabel.TextSize = 16
		iconLabel.Parent = slot

		-- Item name (centred below icon)
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "ItemName"
		nameLabel.Size = UDim2.new(1, -4, 0, 14)
		nameLabel.Position = UDim2.new(0, 2, 0, 32)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = ""
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 8
		nameLabel.TextColor3 = TEXT_WHITE
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = slot

		-- Click button for assignment mode
		local btn = Instance.new("TextButton")
		btn.Name = "ClickArea"
		btn.Size = UDim2.new(1, 0, 1, 0)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.ZIndex = 10
		btn.Parent = slot

		btn.MouseButton1Click:Connect(function()
			if isAssigning then
				HotbarClient.completeAssignment(i)
			end
		end)

		table.insert(slots, slot)
	end

	-- Equip toast (bottom-centre, above hotbar)
	local toast = Instance.new("TextLabel")
	toast.Name = "EquipToast"
	toast.Size = UDim2.new(0, 200, 0, 28)
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -(SLOT_SIZE + 30))
	toast.BackgroundColor3 = TOAST_BG
	toast.BackgroundTransparency = 0.15
	toast.Visible = false
	toast.Text = ""
	toast.Font = Enum.Font.GothamBold
	toast.TextSize = 14
	toast.TextColor3 = TEXT_WHITE
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.Parent = gui

	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 4)
	toastCorner.Parent = toast

	equipToast = toast
	barFrame = bar
	screenGui = gui
end

-- ── Refresh ──────────────────────────────────────────────
local function refreshSlots()
	for i, slot in slots do
		local item = hotbarItems[i]
		local nameLabel = slot:FindFirstChild("ItemName")
		local iconLabel = slot:FindFirstChild("Icon")
		local border = slot:FindFirstChild("Border")

		local isActive = (equippedSlot == i)

		if item then
			local rarityColor = RARITY_COLORS[item.rarity] or RARITY_COLORS.Common

			if nameLabel then
				nameLabel.Text = item.name or "?"
				nameLabel.TextColor3 = TEXT_WHITE
			end
			if iconLabel then
				iconLabel.Text = item.icon or ""
			end
			if border then
				if isActive then
					border.Color = SLOT_SELECTED_BORDER
					border.Thickness = 2.5
				else
					border.Color = rarityColor
					border.Thickness = 2
				end
			end
			slot.BackgroundColor3 = isActive and SLOT_ACTIVE_BG or SLOT_EMPTY_BG
			slot.BackgroundTransparency = 0.08
		else
			if nameLabel then nameLabel.Text = "" end
			if iconLabel then iconLabel.Text = "" end
			if border then
				if isActive then
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

-- ── Equip toast ──────────────────────────────────────────
local function showEquipToast(text: string)
	if not equipToast then
		return
	end

	equipToast.Text = text
	equipToast.Visible = true
	equipToast.TextTransparency = 0
	equipToast.BackgroundTransparency = 0.15

	task.spawn(function()
		task.wait(1.5)
		TweenService:Create(equipToast, TweenInfo.new(0.3), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
		task.wait(0.3)
		equipToast.Visible = false
	end)
end

-- ── Flash slot red ───────────────────────────────────────
local function flashSlotRed(slotIndex: number)
	local slot = slots[slotIndex]
	if not slot then
		return
	end
	local border = slot:FindFirstChild("Border")
	if border then
		border.Color = FULL_FLASH
		TweenService:Create(border, TweenInfo.new(0.4), {
			Color = SLOT_EMPTY_BORDER,
		}):Play()
	end
end

-- ── Assignment mode ──────────────────────────────────────
local function stopPulsing()
	for _, tw in pulsingTweens do
		tw:Cancel()
	end
	pulsingTweens = {}
	refreshSlots()
end

function HotbarClient.startAssignment(inventoryIndex: number, itemIsWeapon: boolean)
	isAssigning = true
	assigningInventoryIndex = inventoryIndex
	assigningIsWeapon = itemIsWeapon

	-- Pulse valid slots
	for i, slot in slots do
		local border = slot:FindFirstChild("Border")
		if not border then
			continue
		end

		local isValid = false
		if itemIsWeapon then
			isValid = (i <= 2) -- weapons go in slots 1-2
		else
			isValid = (i >= 3) -- non-weapons in slots 3-6
		end

		if isValid then
			-- Pulsing white border tween
			local tw = TweenService:Create(border, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				Color = SLOT_PULSE_BORDER,
				Thickness = 3,
			})
			tw:Play()
			table.insert(pulsingTweens, tw)
		end
	end
end

function HotbarClient.completeAssignment(hotbarSlot: number)
	if not isAssigning or not assigningInventoryIndex then
		return
	end

	-- Validate slot restriction
	local isValid = false
	if assigningIsWeapon then
		isValid = (hotbarSlot <= 2)
	else
		isValid = (hotbarSlot >= 3)
	end

	if not isValid then
		flashSlotRed(hotbarSlot)
		return
	end

	-- Fire to server
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remotes then
		local assignRemote = remotes:FindFirstChild(RemoteNames.AssignHotbar)
		if assignRemote then
			assignRemote:FireServer(assigningInventoryIndex, hotbarSlot)
		end
	end

	-- Optimistic local update
	local items = require(script.Parent.InventoryClient).getPlayerItems()
	local item = items[assigningInventoryIndex]
	if item then
		hotbarItems[hotbarSlot] = item
	end

	-- Clean up assignment mode
	isAssigning = false
	assigningInventoryIndex = nil
	assigningIsWeapon = false
	stopPulsing()
end

function HotbarClient.cancelAssignment()
	isAssigning = false
	assigningInventoryIndex = nil
	assigningIsWeapon = false
	stopPulsing()
end

-- ── Equip/Unequip ────────────────────────────────────────
local function equipSlot(slotIndex: number)
	if isAssigning then
		HotbarClient.completeAssignment(slotIndex)
		return
	end

	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remotes then
		return
	end

	-- Toggle: same slot = unequip
	if equippedSlot == slotIndex then
		equippedSlot = nil
		refreshSlots()

		local unequipRemote = remotes:FindFirstChild(RemoteNames.UnequipItem)
		if unequipRemote then
			unequipRemote:FireServer()
		end
		return
	end

	-- Only equip if slot has an item
	local item = hotbarItems[slotIndex]
	if not item then
		return
	end

	equippedSlot = slotIndex
	refreshSlots()

	local equipRemote = remotes:FindFirstChild(RemoteNames.EquipItem)
	if equipRemote then
		equipRemote:FireServer(slotIndex)
	end
end

local function unequipCurrent()
	if not equippedSlot then
		return
	end

	equippedSlot = nil
	refreshSlots()

	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remotes then
		local unequipRemote = remotes:FindFirstChild(RemoteNames.UnequipItem)
		if unequipRemote then
			unequipRemote:FireServer()
		end
	end
end

-- ── Public ───────────────────────────────────────────────

function HotbarClient.updateItems(items)
	-- Map first 6 inventory items to hotbar (for non-assigned items)
	-- But keep explicitly assigned items in their slots
	-- Simple approach: update unassigned slots with inventory order
	-- For now, just keep the hotbar items as explicitly assigned only
	refreshSlots()
end

function HotbarClient.getEquippedSlot()
	return equippedSlot
end

function HotbarClient.getHotbarItems()
	return hotbarItems
end

function HotbarClient.init()
	buildHotbar()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

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
			equipSlot(slotNum)
			return
		end

		-- G key to unequip
		if input.KeyCode == Enum.KeyCode.G then
			unequipCurrent()
			return
		end

		-- Escape cancels assignment mode
		if input.KeyCode == Enum.KeyCode.Escape then
			if isAssigning then
				HotbarClient.cancelAssignment()
			end
		end
	end)

	-- Scroll wheel to cycle equipped slot
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local current = equippedSlot or 0
			local dir = -math.sign(input.Position.Z)
			local newSlot = current + dir
			if newSlot < 1 then
				newSlot = HOTBAR_SLOTS
			elseif newSlot > HOTBAR_SLOTS then
				newSlot = 1
			end
			equipSlot(newSlot)
		end
	end)

	-- WeaponEquipped
	remotes:WaitForChild(RemoteNames.WeaponEquipped).OnClientEvent:Connect(function(itemData)
		if itemData then
			showEquipToast(string.upper(itemData.name or "WEAPON") .. " EQUIPPED")
		end
	end)

	-- WeaponUnequipped
	remotes:WaitForChild(RemoteNames.WeaponUnequipped).OnClientEvent:Connect(function()
		equippedSlot = nil
		refreshSlots()
	end)

	-- ItemEquipped (non-weapon)
	remotes:WaitForChild(RemoteNames.ItemEquipped).OnClientEvent:Connect(function(itemData)
		if itemData then
			showEquipToast(string.upper(itemData.name or "ITEM") .. " EQUIPPED")
		end
	end)

	refreshSlots()
	print("[CAG] HotbarClient initialized (" .. HOTBAR_SLOTS .. " slots, equip system)")
end

return HotbarClient
