--[[
	Client bootstrap — initializes all client-side systems.
	Init order: InteractClient → InventoryClient → HotbarClient → GroundItemClient
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for remotes to be created by server
ReplicatedStorage:WaitForChild("RemoteEvents")
ReplicatedStorage:WaitForChild("Shared")

local InteractClient = require(script.InteractClient)
local InventoryClient = require(script.ui.InventoryClient)
local HotbarClient = require(script.ui.HotbarClient)
local GroundItemClient = require(script.GroundItemClient)

InteractClient.init()
InventoryClient.init()
HotbarClient.init()
GroundItemClient.init()

-- Wire hotbar to receive inventory updates from InventoryClient
InventoryClient.setHotbarCallback(function(items)
	HotbarClient.updateItems(items)
end)

-- Wire equip callback: InventoryClient right-click "EQUIP" → HotbarClient assignment flow
InventoryClient.setEquipCallback(function(inventoryIndex)
	local items = InventoryClient.getPlayerItems()
	local item = items[inventoryIndex]
	if item then
		HotbarClient.startAssignment(inventoryIndex, item.isWeapon or false)
	end
end)

-- Wire inventory open check for GroundItemClient (disable crosshair when inventory open)
GroundItemClient.setInventoryOpenCheck(function()
	return InventoryClient.isOpen()
end)

print("[CAG] Client initialized")
