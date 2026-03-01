--[[
	Server bootstrap — creates remote events and initializes all server systems.
	Init order matters: data systems first, then game systems, then coordinator.
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

-- ── Phase 1: Data systems (no server deps) ──
local PlayerDataServer = require(script.PlayerDataServer)
local InventoryServer = require(script.InventoryServer)
local LootTableServer = require(script.LootTableServer)

PlayerDataServer.init()
InventoryServer.init()
LootTableServer.init()

-- ── Phase 2: Game systems ──
local ContainerServer = require(script.ContainerServer)
local AirdropServer = require(script.AirdropServer)
local WeaponServer = require(script.WeaponServer)
local AIServer = require(script.AIServer)
local ExtractionServer = require(script.ExtractionServer)

ContainerServer.init()
AirdropServer.init()
WeaponServer.init()
AIServer.init()
ExtractionServer.init()

-- ── Phase 3: Squad & Spawn ──
local SquadServer = require(script.SquadServer)
local SpawnServer = require(script.SpawnServer)
SquadServer.init()
SpawnServer.init()

-- ── Phase 4: Round coordinator (depends on all above) ──
local RoundServer = require(script.RoundServer)
RoundServer.init()

-- ── Phase 5: Security (runs after everything) ──
local RemoteThrottleServer = require(script.RemoteThrottleServer)
local AnticheatServer = require(script.AnticheatServer)
RemoteThrottleServer.init()
AnticheatServer.init()

print("[CAG] Server initialized")
