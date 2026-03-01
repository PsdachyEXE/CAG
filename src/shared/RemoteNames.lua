-- Central registry of all remote event/function names
local RemoteNames = {
	-- Interact
	ContainerInteract = "ContainerInteract",
	InteractFailed = "InteractFailed",

	-- Inventory
	InventoryState = "InventoryState",           -- S→C: full container+player contents on open
	ContainerTakeItem = "ContainerTakeItem",      -- C→S: take item at index from container
	ItemTransferred = "ItemTransferred",           -- S→C: confirms transfer, sends updated state
}

return RemoteNames
