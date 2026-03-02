--[[
	GroundItemServer — manages world weapon registration, item dropping, and pickup.
	On startup: registers all WorldWeapon-tagged models as lootable ground items.
	Handles DropItem (remove from inventory → spawn in world) and
	PickupItem (validate → add to inventory → destroy world instance).
	Exports: getGroundItems(), spawnGroundItem(itemData, position), init
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)
local LootTableData = require(ReplicatedStorage.Shared.LootTableData)

local GroundItemServer = {}

-- Module references (set during init)
local InventoryServer = nil
local HitboxService = nil

local PICKUP_RANGE = Config.PICKUP_RANGE + 2 -- +2 tolerance
local WEAPON_TAG = "WorldWeapon"
local ITEM_TAG = "WorldItem"
local DROPPED_TAG = "DroppedItem"

-- Ground item registry: [Instance] = { itemData, state }
local groundItems = {} -- state: "available" / "looting" / "taken"

-- Build lookup from groundModel path → LootTableData entry
local itemByGroundModel = {}

local RARITY_COLORS = {
	Common = BrickColor.new("Medium stone grey"),
	Uncommon = BrickColor.new("Bright green"),
	Rare = BrickColor.new("Really blue"),
	Epic = BrickColor.new("Bright violet"),
	Legendary = BrickColor.new("Bright orange"),
}

local function buildModelIndex()
	for _, item in LootTableData do
		if item.groundModel then
			itemByGroundModel[item.groundModel] = item
		end
	end
end

local function getDistance(player: Player, target: Instance): number?
	local character = player.Character
	if not character then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end

	local part = nil
	if target:IsA("Model") then
		part = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
	elseif target:IsA("BasePart") then
		part = target
	end

	if not part then
		return nil
	end

	return (hrp.Position - part.Position).Magnitude
end

local function getItemDataFromModel(model)
	-- Try to match by path relative to Weapons folder
	-- Structure: Workspace/Weapons/{Category}/{WeaponFolder}/{WeaponModel}
	local weaponsFolder = workspace:FindFirstChild("Weapons")
	if not weaponsFolder then
		return nil
	end

	-- Build path: Weapons/Category/Folder/Model e.g. "Weapons/AR/AK-47/AK-47"
	local weaponFolder = model.Parent -- e.g. AK-47 folder
	local category = weaponFolder and weaponFolder.Parent -- e.g. AR folder
	if category and category.Parent == weaponsFolder then
		local path = "Weapons/" .. category.Name .. "/" .. weaponFolder.Name .. "/" .. model.Name
		return itemByGroundModel[path]
	end

	-- Fallback: try 2-level path (legacy or dropped items placed directly)
	local parent = model.Parent
	if parent and parent.Parent == weaponsFolder then
		local path = "Weapons/" .. parent.Name .. "/" .. model.Name
		return itemByGroundModel[path]
	end

	-- For dropped weapons, check stored attribute
	local storedId = model:GetAttribute("ItemId")
	if storedId then
		for _, item in LootTableData do
			if item.id == storedId then
				return item
			end
		end
	end

	return nil
end

-- ── World weapon registration ────────────────────────────
local function registerWorldWeapon(weapon)
	if groundItems[weapon] then
		return
	end

	local itemData = getItemDataFromModel(weapon)
	if not itemData then
		return
	end

	groundItems[weapon] = {
		itemData = itemData,
		state = "available",
	}
end

-- ── Spawning ─────────────────────────────────────────────
function GroundItemServer.spawnGroundItem(itemData, position: Vector3)
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	local instance = nil

	local randomYRot = CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
	local spawnCF = CFrame.new(position) * randomYRot

	if itemData.isWeapon and itemData.groundModel then
		-- Clone weapon model from Workspace/Weapons/<path>
		local weaponsFolder = workspace:FindFirstChild("Weapons")
		if weaponsFolder then
			local parts = string.split(itemData.groundModel, "/")
			-- parts = {"Weapons", "AR", "AK47"}
			local current = workspace
			for _, part in parts do
				current = current:FindFirstChild(part)
				if not current then
					break
				end
			end

			if current and current ~= workspace then
				instance = current:Clone()
				instance.Parent = workspace

				-- Position at spawn point
				if instance:IsA("Model") then
					local primary = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart")
					if primary then
						if instance.PrimaryPart then
							instance:SetPrimaryPartCFrame(spawnCF)
						else
							primary.CFrame = spawnCF
						end
						primary.Anchored = false
					end
				elseif instance:IsA("BasePart") then
					instance.CFrame = spawnCF
					instance.Anchored = false
				end

				-- Generate hitbox
				if HitboxService then
					HitboxService.generateHitbox(instance)
				end

				-- Tag
				CollectionService:AddTag(instance, WEAPON_TAG)
				CollectionService:AddTag(instance, DROPPED_TAG)
			end
		end
	end

	-- Fallback: generic crate part for non-weapons or if model not found
	if not instance then
		instance = Instance.new("Part")
		instance.Name = itemData.name or "DroppedItem"
		instance.Size = Vector3.new(1, 1, 1)
		instance.CFrame = spawnCF
		instance.Anchored = false
		instance.CanCollide = true
		instance.BrickColor = RARITY_COLORS[itemData.rarity] or RARITY_COLORS.Common
		instance.Material = Enum.Material.SmoothPlastic
		instance.Parent = workspace

		CollectionService:AddTag(instance, ITEM_TAG)
		CollectionService:AddTag(instance, DROPPED_TAG)
	end

	-- Store item ID as attribute for lookup
	instance:SetAttribute("ItemId", itemData.id)

	-- Register
	groundItems[instance] = {
		itemData = itemData,
		state = "available",
	}

	-- Notify all clients
	if remotes then
		local spawnRemote = remotes:FindFirstChild(RemoteNames.GroundItemSpawned)
		if spawnRemote then
			spawnRemote:FireAllClients(instance, itemData)
		end
	end

	return instance
end

-- ── Drop handler ─────────────────────────────────────────
local function handleDrop(player: Player, itemIndex: number)
	if not InventoryServer then
		return
	end

	if type(itemIndex) ~= "number" then
		return
	end
	itemIndex = math.floor(itemIndex)

	local items = InventoryServer.getInventory(player)
	if itemIndex < 1 or itemIndex > #items then
		return
	end

	local item = items[itemIndex]
	if not item then
		return
	end

	-- Remove from inventory
	local removed = InventoryServer.removeItem(player, itemIndex)
	if not removed then
		return
	end

	-- Spawn at player's feet
	local character = player.Character
	local spawnPos = Vector3.new(0, 5, 0) -- fallback
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			spawnPos = hrp.Position - Vector3.new(0, 3, 0)
		end
	end

	GroundItemServer.spawnGroundItem(item, spawnPos)
end

-- ── Pickup handler ───────────────────────────────────────
local function handlePickup(player: Player, itemInstance: Instance)
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remotes then
		return
	end

	-- Validate instance
	if not itemInstance or not itemInstance.Parent then
		return
	end

	local isWeaponTag = CollectionService:HasTag(itemInstance, WEAPON_TAG)
	local isItemTag = CollectionService:HasTag(itemInstance, ITEM_TAG)
	if not isWeaponTag and not isItemTag then
		local failRemote = remotes:FindFirstChild(RemoteNames.PickupFailed)
		if failRemote then
			failRemote:FireClient(player, "INVALID_ITEM")
		end
		return
	end

	-- Check registry
	local entry = groundItems[itemInstance]
	if not entry or entry.state ~= "available" then
		local failRemote = remotes:FindFirstChild(RemoteNames.PickupFailed)
		if failRemote then
			failRemote:FireClient(player, "ALREADY_TAKEN")
		end
		return
	end

	-- Distance check
	local dist = getDistance(player, itemInstance)
	if not dist or dist > PICKUP_RANGE then
		local failRemote = remotes:FindFirstChild(RemoteNames.PickupFailed)
		if failRemote then
			failRemote:FireClient(player, "TOO_FAR")
		end
		return
	end

	-- Inventory full check
	if InventoryServer and InventoryServer.isFull(player) then
		local failRemote = remotes:FindFirstChild(RemoteNames.PickupFailed)
		if failRemote then
			failRemote:FireClient(player, "INVENTORY_FULL")
		end
		return
	end

	-- Lock item
	entry.state = "looting"

	-- Add to inventory
	local itemData = entry.itemData
	if InventoryServer then
		local added = InventoryServer.addItem(player, itemData)
		if not added then
			entry.state = "available"
			local failRemote = remotes:FindFirstChild(RemoteNames.PickupFailed)
			if failRemote then
				failRemote:FireClient(player, "INVENTORY_FULL")
			end
			return
		end
	end

	-- Mark taken
	entry.state = "taken"

	-- Fire confirmations
	local pickupRemote = remotes:FindFirstChild(RemoteNames.ItemPickedUp)
	if pickupRemote then
		pickupRemote:FireClient(player, itemData)
	end

	-- Notify all clients to remove
	local removeRemote = remotes:FindFirstChild(RemoteNames.GroundItemRemoved)
	if removeRemote then
		removeRemote:FireAllClients(itemInstance)
	end

	-- Clean up
	groundItems[itemInstance] = nil
	itemInstance:Destroy()
end

-- ── Public ───────────────────────────────────────────────
function GroundItemServer.getGroundItems()
	return groundItems
end

function GroundItemServer.init()
	buildModelIndex()

	-- Resolve module references
	local serverModules = script.Parent
	local invMod = serverModules:FindFirstChild("InventoryServer")
	if invMod then
		InventoryServer = require(invMod)
	end
	local hitMod = serverModules:FindFirstChild("HitboxService")
	if hitMod then
		HitboxService = require(hitMod)
	end

	-- Register existing world weapons
	local count = 0
	for _, weapon in CollectionService:GetTagged(WEAPON_TAG) do
		registerWorldWeapon(weapon)
		count = count + 1
	end

	-- Watch for newly tagged weapons
	CollectionService:GetInstanceAddedSignal(WEAPON_TAG):Connect(function(weapon)
		registerWorldWeapon(weapon)
	end)

	-- Clean up removed
	CollectionService:GetInstanceRemovedSignal(WEAPON_TAG):Connect(function(weapon)
		groundItems[weapon] = nil
	end)
	CollectionService:GetInstanceRemovedSignal(ITEM_TAG):Connect(function(item)
		groundItems[item] = nil
	end)

	-- Player leaving: nothing to clean (items stay in world)
	-- but we do clean up if an instance is destroyed

	-- Listen for DropItem
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local dropRemote = remotes:WaitForChild(RemoteNames.DropItem)
	dropRemote.OnServerEvent:Connect(function(player, itemIndex)
		task.spawn(function()
			handleDrop(player, itemIndex)
		end)
	end)

	-- Listen for PickupItem
	local pickupRemote = remotes:WaitForChild(RemoteNames.PickupItem)
	pickupRemote.OnServerEvent:Connect(function(player, itemInstance)
		task.spawn(function()
			handlePickup(player, itemInstance)
		end)
	end)

	print("[CAG] GroundItemServer initialized (" .. count .. " world weapons registered)")
end

return GroundItemServer
