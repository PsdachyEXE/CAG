--[[
	HotbarServer — manages hotbar slot assignments and weapon equipping.
	6 slots total. Slots 1-2: weapons only. Slots 3-6: any item.
	On EquipItem: if weapon, clones model and welds to character.
	On UnequipItem: removes equipped weapon model.
	Exports: getHotbar(player), init
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local HotbarServer = {}

-- Module references
local InventoryServer = nil

local HOTBAR_SLOTS = Config.HOTBAR_SLOTS
local EQUIP_OFFSET = Vector3.new(
	Config.WEAPON_EQUIP_OFFSET[1],
	Config.WEAPON_EQUIP_OFFSET[2],
	Config.WEAPON_EQUIP_OFFSET[3]
)
local EQUIP_ROTATION = CFrame.Angles(
	0,
	math.rad(Config.WEAPON_EQUIP_ROTATION[2]),
	0
)
local EQUIPPED_TAG = "EquippedWeapon"

-- Per-player hotbar: [Player] = { slots = {[1]=itemData,...}, equippedSlot = nil }
local hotbars = {}

-- Per-player equipped weapon instance: [Player] = Instance
local equippedWeapons = {}

local function initHotbar(player)
	if not hotbars[player] then
		hotbars[player] = {
			slots = {},
			equippedSlot = nil,
		}
	end
end

local function removeEquippedWeapon(player)
	local existing = equippedWeapons[player]
	if existing and existing.Parent then
		existing:Destroy()
	end
	equippedWeapons[player] = nil
end

local function attachWeaponToCharacter(player, itemData)
	local character = player.Character
	if not character then
		return false
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end

	-- Remove any existing equipped weapon
	removeEquippedWeapon(player)

	if not itemData.id then
		return false
	end

	-- Clone from ReplicatedStorage.WeaponTemplates (survives pickup/destruction)
	local templates = ReplicatedStorage:FindFirstChild("WeaponTemplates")
	if not templates then
		return false
	end

	local template = templates:FindFirstChild(itemData.id)
	if not template then
		return false
	end

	-- Clone the weapon
	local weaponClone = template:Clone()
	weaponClone.Name = "Equipped_" .. (itemData.name or "Weapon")

	-- Unanchor all parts
	if weaponClone:IsA("Model") then
		for _, desc in weaponClone:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.Anchored = false
				desc.CanCollide = false
			end
		end
	elseif weaponClone:IsA("BasePart") then
		weaponClone.Anchored = false
		weaponClone.CanCollide = false
	end

	-- Remove any existing hitbox from clone
	local existingHitbox = weaponClone:FindFirstChild("Hitbox")
	if existingHitbox then
		existingHitbox:Destroy()
	end

	-- Get primary part
	local weaponPart = nil
	if weaponClone:IsA("Model") then
		weaponPart = weaponClone.PrimaryPart or weaponClone:FindFirstChildWhichIsA("BasePart")
	elseif weaponClone:IsA("BasePart") then
		weaponPart = weaponClone
	end

	if not weaponPart then
		weaponClone:Destroy()
		return false
	end

	-- Position weapon relative to HRP
	local targetCF = hrp.CFrame * CFrame.new(EQUIP_OFFSET) * EQUIP_ROTATION

	if weaponClone:IsA("Model") and weaponClone.PrimaryPart then
		weaponClone:SetPrimaryPartCFrame(targetCF)
	else
		weaponPart.CFrame = targetCF
	end

	-- Weld to HRP
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = weaponPart
	weld.Part1 = hrp
	weld.Parent = weaponPart

	weaponClone.Parent = character
	CollectionService:AddTag(weaponClone, EQUIPPED_TAG)

	equippedWeapons[player] = weaponClone
	return true
end

-- ── Handlers ─────────────────────────────────────────────

local function handleAssignHotbar(player: Player, inventoryIndex: number, hotbarSlot: number)
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remotes then
		return
	end

	initHotbar(player)
	local hb = hotbars[player]

	-- Validate hotbar slot
	if type(hotbarSlot) ~= "number" then
		return
	end
	hotbarSlot = math.floor(hotbarSlot)
	if hotbarSlot < 1 or hotbarSlot > HOTBAR_SLOTS then
		return
	end

	-- Validate inventory index
	if type(inventoryIndex) ~= "number" then
		return
	end
	inventoryIndex = math.floor(inventoryIndex)

	if not InventoryServer then
		return
	end

	local items = InventoryServer.getInventory(player)
	if inventoryIndex < 1 or inventoryIndex > #items then
		return
	end

	local item = items[inventoryIndex]
	if not item then
		return
	end

	-- Weapon restriction: slots 1-2 are weapons only
	if hotbarSlot <= 2 and not item.isWeapon then
		return
	end

	-- Assign to slot (swap if occupied)
	local existingItem = hb.slots[hotbarSlot]
	hb.slots[hotbarSlot] = item

	-- If the equipped slot was changed, update weapon
	if hb.equippedSlot == hotbarSlot then
		if item.isWeapon then
			attachWeaponToCharacter(player, item)
			local equipRemote = remotes:FindFirstChild(RemoteNames.WeaponEquipped)
			if equipRemote then
				equipRemote:FireClient(player, item)
			end
		else
			removeEquippedWeapon(player)
			local unequipRemote = remotes:FindFirstChild(RemoteNames.WeaponUnequipped)
			if unequipRemote then
				unequipRemote:FireClient(player)
			end
		end
	end
end

local function handleEquip(player: Player, slotIndex: number)
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remotes then
		return
	end

	initHotbar(player)
	local hb = hotbars[player]

	if type(slotIndex) ~= "number" then
		return
	end
	slotIndex = math.floor(slotIndex)
	if slotIndex < 1 or slotIndex > HOTBAR_SLOTS then
		return
	end

	-- Toggle: if already equipped, unequip
	if hb.equippedSlot == slotIndex then
		hb.equippedSlot = nil
		removeEquippedWeapon(player)

		local unequipRemote = remotes:FindFirstChild(RemoteNames.WeaponUnequipped)
		if unequipRemote then
			unequipRemote:FireClient(player)
		end
		return
	end

	local item = hb.slots[slotIndex]
	if not item then
		return
	end

	hb.equippedSlot = slotIndex

	if item.isWeapon then
		local attached = attachWeaponToCharacter(player, item)
		if attached then
			local equipRemote = remotes:FindFirstChild(RemoteNames.WeaponEquipped)
			if equipRemote then
				equipRemote:FireClient(player, item)
			end
		end
	else
		-- Non-weapon equip
		removeEquippedWeapon(player) -- remove any weapon
		local itemRemote = remotes:FindFirstChild(RemoteNames.ItemEquipped)
		if itemRemote then
			itemRemote:FireClient(player, item)
		end
	end
end

local function handleUnequip(player: Player)
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remotes then
		return
	end

	initHotbar(player)
	local hb = hotbars[player]

	if hb.equippedSlot then
		hb.equippedSlot = nil
		removeEquippedWeapon(player)

		local unequipRemote = remotes:FindFirstChild(RemoteNames.WeaponUnequipped)
		if unequipRemote then
			unequipRemote:FireClient(player)
		end
	end
end

-- ── Public ───────────────────────────────────────────────

function HotbarServer.getHotbar(player)
	initHotbar(player)
	return hotbars[player]
end

function HotbarServer.init()
	-- Resolve references
	local serverModules = script.Parent
	local invMod = serverModules:FindFirstChild("InventoryServer")
	if invMod then
		InventoryServer = require(invMod)
	end

	-- Init hotbars for existing players
	for _, plr in Players:GetPlayers() do
		initHotbar(plr)
	end

	Players.PlayerAdded:Connect(function(plr)
		initHotbar(plr)
	end)

	Players.PlayerRemoving:Connect(function(plr)
		removeEquippedWeapon(plr)
		hotbars[plr] = nil
		equippedWeapons[plr] = nil
	end)

	-- Character respawn: re-equip weapon
	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function()
			local hb = hotbars[plr]
			if hb and hb.equippedSlot then
				local item = hb.slots[hb.equippedSlot]
				if item and item.isWeapon then
					task.spawn(function()
						task.wait(0.5) -- wait for character to load
						attachWeaponToCharacter(plr, item)
					end)
				end
			end
		end)
	end)

	-- Listen for remotes
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	remotes:WaitForChild(RemoteNames.AssignHotbar).OnServerEvent:Connect(function(player, inventoryIndex, hotbarSlot)
		task.spawn(function()
			handleAssignHotbar(player, inventoryIndex, hotbarSlot)
		end)
	end)

	remotes:WaitForChild(RemoteNames.EquipItem).OnServerEvent:Connect(function(player, slotIndex)
		task.spawn(function()
			handleEquip(player, slotIndex)
		end)
	end)

	remotes:WaitForChild(RemoteNames.UnequipItem).OnServerEvent:Connect(function(player)
		task.spawn(function()
			handleUnequip(player)
		end)
	end)

	print("[CAG] HotbarServer initialized (" .. HOTBAR_SLOTS .. " slots)")
end

return HotbarServer
