-- Central registry of all remote event/function names
local RemoteNames = {
	-- Interact
	ContainerInteract = "ContainerInteract",
	InteractFailed = "InteractFailed",

	-- Inventory
	InventoryState = "InventoryState",           -- S→C: full container+player contents on open
	ContainerTakeItem = "ContainerTakeItem",      -- C→S: take item at index from container
	ItemTransferred = "ItemTransferred",           -- S→C: confirms transfer, sends updated state

	-- Ground items
	DropItem = "DropItem",                         -- C→S: drop item from inventory by index
	PickupItem = "PickupItem",                     -- C→S: pick up world item instance
	PickupFailed = "PickupFailed",                 -- S→C: pickup rejected with reason
	ItemPickedUp = "ItemPickedUp",                 -- S→C: confirm pickup with itemData
	GroundItemSpawned = "GroundItemSpawned",       -- S→All: new ground item appeared
	GroundItemRemoved = "GroundItemRemoved",       -- S→All: ground item removed from world

	-- Hotbar / Equip
	AssignHotbar = "AssignHotbar",                 -- C→S: assign inventory item to hotbar slot
	EquipItem = "EquipItem",                       -- C→S: equip hotbar slot
	UnequipItem = "UnequipItem",                   -- C→S: unequip current item
	WeaponEquipped = "WeaponEquipped",             -- S→C: weapon model attached to character
	WeaponUnequipped = "WeaponUnequipped",         -- S→C: weapon model removed
	ItemEquipped = "ItemEquipped",                 -- S→C: non-weapon item equipped
}

return RemoteNames
