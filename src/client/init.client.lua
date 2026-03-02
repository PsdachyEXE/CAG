--[[
	Client bootstrap — initializes all client-side systems.
	Init order: InteractClient → InventoryClient → HotbarClient → GroundItemClient
	           → RecoilClient → ViewModelClient → HUDClient → WeaponCombatClient
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for server to create remotes and shared modules
ReplicatedStorage:WaitForChild("RemoteEvents")
ReplicatedStorage:WaitForChild("Shared")

-- ── Core systems ──────────────────────────────────────────
local InteractClient   = require(script.InteractClient)
local InventoryClient  = require(script.ui.InventoryClient)
local HotbarClient     = require(script.ui.HotbarClient)
local GroundItemClient = require(script.GroundItemClient)

InteractClient.init()
InventoryClient.init()
HotbarClient.init()
GroundItemClient.init()

-- Hotbar UI stays in sync when inventory changes
InventoryClient.setHotbarCallback(function(items)
	HotbarClient.updateItems(items)
end)

-- Left-click inventory slot → assign to first free hotbar slot + equip + close
InventoryClient.setDirectEquipCallback(function(inventoryIndex, item)
	HotbarClient.directAssignAndEquip(inventoryIndex, item)
	InventoryClient.close()
end)

-- Left panel of inventory shows nearby ground items
InventoryClient.setVicinityProvider(function()
	return GroundItemClient.getNearbyItems()
end)

-- Disable crosshair pickup prompt while inventory is open
GroundItemClient.setInventoryOpenCheck(function()
	return InventoryClient.isOpen()
end)

-- ── Combat systems ────────────────────────────────────────
local RecoilClient       = require(script.RecoilClient)
local ViewModelClient    = require(script.ViewModelClient)
local HUDClient          = require(script.ui.HUDClient)
local WeaponCombatClient = require(script.WeaponCombatClient)

RecoilClient.init()
ViewModelClient.init()
HUDClient.init()
WeaponCombatClient.init()

-- Wire combat module dependencies
ViewModelClient.setRecoilModule(RecoilClient)
WeaponCombatClient.setViewModelClient(ViewModelClient)
WeaponCombatClient.setRecoilClient(RecoilClient)
WeaponCombatClient.setHUDClient(HUDClient)

-- Disable firing while inventory is open
WeaponCombatClient.setInventoryOpenCheck(function()
	return InventoryClient.isOpen()
end)

-- Inventory open  → release mouse lock so player can click inventory slots
-- Inventory close → re-lock mouse if a weapon is still equipped
InventoryClient.setOnOpenCallback(function()
	WeaponCombatClient.onInventoryOpened()
end)

InventoryClient.setOnCloseCallback(function()
	WeaponCombatClient.onInventoryClosed()
end)

print("[CAG] Client initialized")
