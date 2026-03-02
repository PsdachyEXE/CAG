-- Central registry of all remote event/function names
local RemoteNames = {
	-- Interact
	ContainerInteract = "ContainerInteract",
	InteractFailed = "InteractFailed",

	-- Inventory
	InventoryState = "InventoryState",
	ContainerTakeItem = "ContainerTakeItem",
	ItemTransferred = "ItemTransferred",

	-- Ground items
	DropItem = "DropItem",
	PickupItem = "PickupItem",
	PickupFailed = "PickupFailed",
	ItemPickedUp = "ItemPickedUp",
	GroundItemSpawned = "GroundItemSpawned",
	GroundItemRemoved = "GroundItemRemoved",

	-- Hotbar / Equip
	AssignHotbar = "AssignHotbar",
	EquipItem = "EquipItem",
	UnequipItem = "UnequipItem",
	WeaponEquipped = "WeaponEquipped",
	WeaponUnequipped = "WeaponUnequipped",
	ItemEquipped = "ItemEquipped",

	-- Combat
	WeaponFired = "WeaponFired",                   -- C→S: origin, direction, weaponId, isADS, pelletCount
	HitConfirmed = "HitConfirmed",                 -- S→C: isHeadshot, damage, hitPosition
	ReloadStarted = "ReloadStarted",               -- C→S: weapon reload begun
	ReloadComplete = "ReloadComplete",             -- S→C: reload finished server-side
	PlayerKilled = "PlayerKilled",                 -- S→All: killerName, victimName, weaponName
}

return RemoteNames
