--[[
	Server bootstrap — creates remote events and initializes all server systems.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

-- Create all remote events
local remoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents")

for _, name in RemoteNames do
	if not remoteFolder:FindFirstChild(name) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remoteFolder
	end
end

-- ── Data systems ──
local LootTableServer = require(script.LootTableServer)
local InventoryServer = require(script.InventoryServer)

LootTableServer.init()
InventoryServer.init()

-- ── Interact system ──
local InteractServer = require(script.InteractServer)
InteractServer.init()

print("[CAG] Server initialized")
