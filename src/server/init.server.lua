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

-- Initialize server modules
local WeaponServer = require(script.WeaponServer)
local AIServer = require(script.AIServer)
local ExtractionServer = require(script.ExtractionServer)

WeaponServer.init()
AIServer.init()
ExtractionServer.init()

print("[CAG] Server initialized")
