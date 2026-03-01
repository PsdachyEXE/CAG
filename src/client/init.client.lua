--[[
	Client bootstrap — initializes all client-side systems.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for remotes to be created by server
ReplicatedStorage:WaitForChild("RemoteEvents")
ReplicatedStorage:WaitForChild("Shared")

local InteractClient = require(script.InteractClient)
local InventoryClient = require(script.ui.InventoryClient)

InteractClient.init()
InventoryClient.init()

print("[CAG] Client initialized")
