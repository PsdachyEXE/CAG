--[[
	Client bootstrap — initializes all client-side systems.
	Init order: InteractClient → InventoryClient → HotbarClient
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for remotes to be created by server
ReplicatedStorage:WaitForChild("RemoteEvents")
ReplicatedStorage:WaitForChild("Shared")

local InteractClient = require(script.InteractClient)
local InventoryClient = require(script.ui.InventoryClient)
local HotbarClient = require(script.ui.HotbarClient)

InteractClient.init()
InventoryClient.init()
HotbarClient.init()

-- Wire hotbar to receive inventory updates from InventoryClient
InventoryClient.setHotbarCallback(function(items)
	HotbarClient.updateItems(items)
end)

print("[CAG] Client initialized")
