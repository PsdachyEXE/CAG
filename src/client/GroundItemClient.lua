--[[
	GroundItemClient — crosshair-based detection for ground weapons/items.
	Casts ray from camera through screen centre every 0.1s.
	Shows BillboardGui interact prompt (same style as container E prompt).
	E key to pick up, fires PickupItem to server.
	Listens for GroundItemSpawned/GroundItemRemoved.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local GroundItemClient = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local RAY_LENGTH = Config.CROSSHAIR_RAY_LENGTH or 10
local COOLDOWN = Config.INTERACT_COOLDOWN
local FADE_TIME = 0.15

local currentTarget = nil    -- Instance currently showing prompt
local promptGui = nil        -- BillboardGui for E prompt
local nameGui = nil          -- BillboardGui for item name above prompt
local onCooldown = false
local isInventoryOpen = false -- set by InventoryClient

-- Local registry of ground items: [Instance] = itemData
local groundItemRegistry = {}

-- ── Callback for checking if inventory UI is open ────────
local inventoryOpenCheck = nil

function GroundItemClient.setInventoryOpenCheck(fn)
	inventoryOpenCheck = fn
end

-- ── Prompt creation ──────────────────────────────────────
local function createPrompt()
	-- E prompt (same as InteractClient style)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PickupPrompt"
	billboard.Size = UDim2.new(0, 48, 0, 48)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = RAY_LENGTH + 2
	billboard.Enabled = false

	local bg = Instance.new("Frame")
	bg.Name = "BG"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(26, 26, 46)
	bg.BackgroundTransparency = 0.25
	bg.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = bg

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Border"
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2
	stroke.Parent = bg

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.15, 0),
		NumberSequenceKeypoint.new(0.85, 0),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	gradient.Parent = stroke

	local bgGradient = Instance.new("UIGradient")
	bgGradient.Name = "BGGradient"
	bgGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.3, 0),
		NumberSequenceKeypoint.new(0.7, 0),
		NumberSequenceKeypoint.new(1, 0.7),
	})
	bgGradient.Parent = bg

	local eLabel = Instance.new("TextLabel")
	eLabel.Name = "KeyLabel"
	eLabel.Size = UDim2.new(1, 0, 1, 0)
	eLabel.BackgroundTransparency = 1
	eLabel.Text = "E"
	eLabel.Font = Enum.Font.FredokaOne
	eLabel.TextSize = 24
	eLabel.TextColor3 = Color3.new(1, 1, 1)
	eLabel.Parent = bg

	promptGui = billboard

	-- Name label billboard (positioned above E prompt)
	local nameBB = Instance.new("BillboardGui")
	nameBB.Name = "PickupName"
	nameBB.Size = UDim2.new(0, 140, 0, 22)
	nameBB.StudsOffset = Vector3.new(0, 3.8, 0) -- 8px above the E prompt
	nameBB.AlwaysOnTop = true
	nameBB.MaxDistance = RAY_LENGTH + 2
	nameBB.Enabled = false

	local nameBG = Instance.new("Frame")
	nameBG.Name = "BG"
	nameBG.Size = UDim2.new(1, 0, 1, 0)
	nameBG.BackgroundColor3 = Color3.fromRGB(13, 13, 18) -- #0D0D12
	nameBG.BackgroundTransparency = 0.2
	nameBG.Parent = nameBB

	local nameCorner = Instance.new("UICorner")
	nameCorner.CornerRadius = UDim.new(0, 3)
	nameCorner.Parent = nameBG

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemLabel"
	nameLabel.Size = UDim2.new(1, -6, 1, 0)
	nameLabel.Position = UDim2.new(0, 3, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = ""
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = nameBG

	nameGui = nameBB
end

local function getItemPart(instance)
	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart")
	elseif instance:IsA("BasePart") then
		return instance
	end
	return nil
end

local function showPrompt(target)
	if currentTarget == target then
		return
	end

	local part = getItemPart(target)
	if not part then
		return
	end

	currentTarget = target

	-- E prompt
	promptGui.Adornee = part
	promptGui.Parent = part
	promptGui.Enabled = true

	local bg = promptGui:FindFirstChild("BG")
	if bg then
		bg.BackgroundTransparency = 1
		local eLabel = bg:FindFirstChild("KeyLabel")
		if eLabel then eLabel.TextTransparency = 1 end
		local border = bg:FindFirstChild("Border")
		if border then border.Transparency = 1 end

		TweenService:Create(bg, TweenInfo.new(FADE_TIME), { BackgroundTransparency = 0.25 }):Play()
		if eLabel then TweenService:Create(eLabel, TweenInfo.new(FADE_TIME), { TextTransparency = 0 }):Play() end
		if border then TweenService:Create(border, TweenInfo.new(FADE_TIME), { Transparency = 0 }):Play() end
	end

	-- Name label
	nameGui.Adornee = part
	nameGui.Parent = part
	nameGui.Enabled = true

	local itemData = groundItemRegistry[target]
	local nameBG = nameGui:FindFirstChild("BG")
	if nameBG then
		local itemLabel = nameBG:FindFirstChild("ItemLabel")
		if itemLabel and itemData then
			itemLabel.Text = string.upper(itemData.name or "ITEM")
		elseif itemLabel then
			-- Try attribute
			local attrName = target:GetAttribute("ItemName") or target.Name
			itemLabel.Text = string.upper(attrName)
		end
	end
end

local function hidePrompt()
	if not currentTarget then
		return
	end

	currentTarget = nil

	local bg = promptGui:FindFirstChild("BG")
	if bg then
		local eLabel = bg:FindFirstChild("KeyLabel")
		local border = bg:FindFirstChild("Border")

		TweenService:Create(bg, TweenInfo.new(FADE_TIME), { BackgroundTransparency = 1 }):Play()
		if eLabel then TweenService:Create(eLabel, TweenInfo.new(FADE_TIME), { TextTransparency = 1 }):Play() end
		if border then TweenService:Create(border, TweenInfo.new(FADE_TIME), { Transparency = 1 }):Play() end
	end

	task.spawn(function()
		task.wait(FADE_TIME)
		if currentTarget == nil then
			promptGui.Enabled = false
			nameGui.Enabled = false
		end
	end)
end

-- ── Crosshair raycast ────────────────────────────────────
local function crosshairRaycast()
	if not camera then
		camera = workspace.CurrentCamera
	end
	if not camera then
		return nil
	end

	local viewportSize = camera.ViewportSize
	local centre = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
	local ray = camera:ViewportPointToRay(centre.X, centre.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = player.Character
	if character then
		params.FilterDescendantsInstances = { character }
	end

	local result = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
	if not result or not result.Instance then
		return nil
	end

	local hitPart = result.Instance

	-- Check if we hit a WeaponHitbox
	if CollectionService:HasTag(hitPart, "WeaponHitbox") then
		-- Return the parent weapon model
		local weapon = hitPart.Parent
		if weapon and (CollectionService:HasTag(weapon, "WorldWeapon") or CollectionService:HasTag(weapon, "WorldItem")) then
			return weapon
		end
	end

	-- Check if we hit a WorldItem directly
	if CollectionService:HasTag(hitPart, "WorldItem") then
		return hitPart
	end

	-- Check if parent is a tagged model
	local parent = hitPart.Parent
	if parent and (CollectionService:HasTag(parent, "WorldWeapon") or CollectionService:HasTag(parent, "WorldItem")) then
		return parent
	end

	return nil
end

-- ── Public ───────────────────────────────────────────────

-- Returns ground items within 2× pickup range as
-- { instance, itemData, dist } sorted closest-first.
-- Used by InventoryClient to populate the VICINITY panel.
function GroundItemClient.getNearbyItems()
	local character = player.Character
	if not character then return {} end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return {} end

	local RANGE = (Config.PICKUP_RANGE or 6) * 2
	local nearby = {}

	for instance, itemData in groundItemRegistry do
		local part = getItemPart(instance)
		if part and part.Parent then
			local dist = (hrp.Position - part.Position).Magnitude
			if dist <= RANGE then
				table.insert(nearby, { instance = instance, itemData = itemData, dist = dist })
			end
		end
	end

	table.sort(nearby, function(a, b) return a.dist < b.dist end)
	return nearby
end

function GroundItemClient.init()
	createPrompt()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local pickupRemote = remotes:WaitForChild(RemoteNames.PickupItem)

	-- Crosshair detection every 0.1s
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum = accum + dt
		if accum < 0.1 then
			return
		end
		accum = 0

		-- Don't detect while inventory is open
		if inventoryOpenCheck and inventoryOpenCheck() then
			if currentTarget then
				hidePrompt()
			end
			return
		end

		local hit = crosshairRaycast()
		if hit then
			showPrompt(hit)
		elseif currentTarget then
			hidePrompt()
		end
	end)

	-- E key to pick up
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.E then
			if currentTarget and not onCooldown then
				onCooldown = true
				pickupRemote:FireServer(currentTarget)

				task.spawn(function()
					task.wait(COOLDOWN)
					onCooldown = false
				end)
			end
		end
	end)

	-- GroundItemSpawned — register locally
	remotes:WaitForChild(RemoteNames.GroundItemSpawned).OnClientEvent:Connect(function(instance, itemData)
		if instance then
			groundItemRegistry[instance] = itemData
		end
	end)

	-- GroundItemRemoved — deregister
	remotes:WaitForChild(RemoteNames.GroundItemRemoved).OnClientEvent:Connect(function(instance)
		if instance then
			groundItemRegistry[instance] = nil
			if currentTarget == instance then
				hidePrompt()
			end
		end
	end)

	-- ItemPickedUp — local confirmation (handled by inventory refresh)
	remotes:WaitForChild(RemoteNames.ItemPickedUp).OnClientEvent:Connect(function(_itemData)
		-- InventoryClient will receive updated state through its own channels
	end)

	-- PickupFailed
	remotes:WaitForChild(RemoteNames.PickupFailed).OnClientEvent:Connect(function(_reason)
		-- Could show a toast, but InventoryClient handles INVENTORY_FULL
	end)

	-- Register all existing ground items that are already tagged
	for _, weapon in CollectionService:GetTagged("WorldWeapon") do
		local id = weapon:GetAttribute("ItemId")
		if id then
			for _, item in require(ReplicatedStorage.Shared.LootTableData) do
				if item.id == id then
					groundItemRegistry[weapon] = item
					break
				end
			end
		end
	end

	for _, item in CollectionService:GetTagged("WorldItem") do
		local id = item:GetAttribute("ItemId")
		if id then
			for _, itemEntry in require(ReplicatedStorage.Shared.LootTableData) do
				if itemEntry.id == id then
					groundItemRegistry[item] = itemEntry
					break
				end
			end
		end
	end

	print("[CAG] GroundItemClient initialized")
end

return GroundItemClient
