--[[
	SpawnServer — manages player spawn positions.
	Distributes spawns around map edges, ensures minimum spacing.
	Squad members spawn near leader. No respawn during round (spectate only).
	Exports: spawnPlayer, getSpawnPosition
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local SpawnServer = {}

-- Module references
local SquadServer = nil
local RoundServer = nil

local usedSpawnPositions = {} -- [index] = true (used this round)

local function getAvailableSpawnPosition(nearPosition: Vector3?): Vector3
	local positions = Config.Spawn.SpawnPositions
	local bestPos = positions[1]
	local bestDist = 0

	-- If near a position requested (squad spawn), find closest available
	if nearPosition then
		local closestDist = math.huge
		for i, pos in positions do
			if not usedSpawnPositions[i] then
				local dist = (pos - nearPosition).Magnitude
				if dist < closestDist and dist <= Config.Spawn.SquadSpawnRadius then
					closestDist = dist
					bestPos = pos
					bestDist = i
				end
			end
		end
		if bestDist > 0 then
			usedSpawnPositions[bestDist] = true
			return bestPos
		end
	end

	-- Find position with maximum distance from all used positions
	local maxMinDist = 0
	local bestIndex = 1

	for i, pos in positions do
		if usedSpawnPositions[i] then
			continue
		end

		local minDistToUsed = math.huge
		for j, _ in usedSpawnPositions do
			local usedPos = positions[j]
			if usedPos then
				local dist = (pos - usedPos).Magnitude
				minDistToUsed = math.min(minDistToUsed, dist)
			end
		end

		if minDistToUsed > maxMinDist then
			maxMinDist = minDistToUsed
			bestPos = pos
			bestIndex = i
		end
	end

	usedSpawnPositions[bestIndex] = true
	return bestPos
end

function SpawnServer.spawnPlayer(plr: Player)
	local character = plr.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	-- Check if player is in a squad and if leader has spawned
	local nearPos = nil
	if SquadServer then
		local squad = SquadServer.getSquad(plr)
		if squad and squad.leader ~= plr and squad.leader.Character then
			local leaderHRP = squad.leader.Character:FindFirstChild("HumanoidRootPart")
			if leaderHRP then
				nearPos = leaderHRP.Position
			end
		end
	end

	local spawnPos = getAvailableSpawnPosition(nearPos)
	hrp.CFrame = CFrame.new(spawnPos + Vector3.new(0, 3, 0))
end

function SpawnServer.getSpawnPosition(plr: Player): Vector3
	local nearPos = nil
	if SquadServer then
		local squad = SquadServer.getSquad(plr)
		if squad and squad.leader ~= plr and squad.leader.Character then
			local leaderHRP = squad.leader.Character:FindFirstChild("HumanoidRootPart")
			if leaderHRP then
				nearPos = leaderHRP.Position
			end
		end
	end
	return getAvailableSpawnPosition(nearPos)
end

function SpawnServer.resetSpawns()
	usedSpawnPositions = {}
end

function SpawnServer.init()
	local serverModules = script.Parent

	local squadModule = serverModules:FindFirstChild("SquadServer")
	if squadModule then
		SquadServer = require(squadModule)
	end

	local roundModule = serverModules:FindFirstChild("RoundServer")
	if roundModule then
		RoundServer = require(roundModule)
	end

	-- Spawn players when their character loads during a round
	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function(_character)
			-- Small delay to let character fully load
			task.wait(0.5)

			-- Only auto-spawn if round is active
			if RoundServer and RoundServer.isRoundActive() then
				SpawnServer.spawnPlayer(plr)
			end
		end)
	end)

	-- Also connect for existing players
	for _, plr in Players:GetPlayers() do
		plr.CharacterAdded:Connect(function(_character)
			task.wait(0.5)
			if RoundServer and RoundServer.isRoundActive() then
				SpawnServer.spawnPlayer(plr)
			end
		end)
	end

	print("[CAG] SpawnServer initialized")
end

return SpawnServer
