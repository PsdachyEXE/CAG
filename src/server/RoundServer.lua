--[[
	RoundServer — master round controller.
	States: Waiting → Active → Extracting → Ended
	Coordinates AIServer, ExtractionServer, AirdropServer, ContainerServer.
	Handles XP awards, kill tracking, round lifecycle.
	Exports: getRoundState, getCurrentMatchTime, isRoundActive,
	         onPlayerKill, onPlayerDied, onPlayerExtracted
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local RoundServer = {}

-- Module references (set during init)
local PlayerDataServer = nil
local InventoryServer = nil
local AIServer = nil
local ExtractionServer = nil
local AirdropServer = nil
local ContainerServer = nil

local ROUND_STATE = {
	Waiting = "Waiting",
	Active = "Active",
	Extracting = "Extracting",
	Ended = "Ended",
}

local currentState = ROUND_STATE.Waiting
local matchStartTime = 0
local matchDuration = 0
local playerKills = {}       -- [player] = kill count
local alivePlayers = {}      -- [player] = true
local extractedPlayers = {}  -- [player] = true
local airdropTriggered = false
local extractionActivated = false
local roundActive = false

-- ── Helpers ──────────────────────────────────────────────

local function fireLeaderboardUpdate()
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remotes then
		return
	end
	local remote = remotes:FindFirstChild(RemoteNames.LeaderboardUpdate)
	if not remote then
		return
	end

	local data = {}
	for _, p in Players:GetPlayers() do
		local status = "In Match"
		if extractedPlayers[p] then
			status = "Extracted"
		elseif not alivePlayers[p] and roundActive then
			status = "Eliminated"
		end

		local itemCount = 0
		if InventoryServer then
			local inv = InventoryServer.getInventory(p)
			if inv then
				itemCount = #inv
			end
		end

		table.insert(data, {
			name = p.Name,
			kills = playerKills[p] or 0,
			items = itemCount,
			status = status,
		})
	end

	remote:FireAllClients(data)
end

local function fireStateChange(state: string)
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remotes then
		return
	end
	local remote = remotes:FindFirstChild(RemoteNames.RoundStateChanged)
	if remote then
		remote:FireAllClients(state)
	end
end

local function fireMatchTime(remaining: number)
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remotes then
		return
	end
	local remote = remotes:FindFirstChild(RemoteNames.MatchTimeUpdate)
	if remote then
		remote:FireAllClients(remaining)
	end
end

local function getWaveReached(): number
	if AIServer and AIServer.getCurrentWave then
		return AIServer.getCurrentWave()
	end
	return 0
end

local function calculateXP(player: Player, extracted: boolean): number
	local xp = Config.Round.XPParticipation

	-- Kill bonus
	local kills = playerKills[player] or 0
	xp = xp + (kills * Config.Round.XPPerKill)

	-- Extraction bonus
	if extracted then
		xp = xp + Config.Round.XPExtraction

		-- Volatile item value bonus
		if InventoryServer then
			xp = xp + InventoryServer.calculateExtractionBonus(player)
		end
	end

	-- Wave bonus
	xp = xp + (getWaveReached() * Config.Round.XPPerWave)

	return xp
end

local function countAlivePlayers(): number
	local count = 0
	for p, alive in alivePlayers do
		if alive and p.Parent then
			count = count + 1
		end
	end
	return count
end

-- ── Round lifecycle ──────────────────────────────────────

local function endRound(reason: string)
	if currentState == ROUND_STATE.Ended then
		return
	end

	currentState = ROUND_STATE.Ended
	roundActive = false
	fireStateChange(ROUND_STATE.Ended)

	-- Stop AI waves
	if AIServer and AIServer.stopWaves then
		AIServer.stopWaves()
	end

	-- Deactivate extraction zone
	if ExtractionServer and ExtractionServer.deactivate then
		ExtractionServer.deactivate()
	end

	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remotes then
		return
	end
	local roundEndRemote = remotes:FindFirstChild(RemoteNames.RoundEnd)
	if not roundEndRemote then
		return
	end

	local waveReached = getWaveReached()

	-- Process each player
	for _, player in Players:GetPlayers() do
		local extracted = extractedPlayers[player] == true
		local xpEarned = calculateXP(player, extracted)

		-- Award persistent XP and update stats
		if PlayerDataServer then
			PlayerDataServer.addXP(player, xpEarned)

			local data = PlayerDataServer.getData(player)
			if data then
				data.totalMatches = data.totalMatches + 1
				if extracted then
					data.totalExtractions = data.totalExtractions + 1
				end
			end

			PlayerDataServer.save(player)
		end

		-- Handle volatile inventory
		if InventoryServer then
			if extracted then
				local extRemote = remotes:FindFirstChild(RemoteNames.VolatileItemsExtracted)
				if extRemote then
					extRemote:FireClient(player, InventoryServer.getInventory(player))
				end
			else
				local lostRemote = remotes:FindFirstChild(RemoteNames.VolatileItemsLost)
				if lostRemote then
					lostRemote:FireClient(player, InventoryServer.getInventory(player))
				end
			end
			InventoryServer.wipeVolatile(player)
		end

		-- Build loot display list
		local lootNames = {}
		if InventoryServer then
			lootNames = InventoryServer.getItemNames(player)
		end

		-- Fire round end to this player
		roundEndRemote:FireClient(player, {
			playerName = player.Name,
			extracted = extracted,
			xp = xpEarned,
			loot = #lootNames > 0 and lootNames or { "No loot this round" },
			streak = playerKills[player] or 0,
			waveReached = waveReached,
		})
	end

	print("[CAG] Round ended: " .. reason .. " (wave " .. waveReached .. ")")

	-- Intermission then reset
	task.spawn(function()
		task.wait(Config.Round.IntermissionDuration)
		RoundServer._resetRound()
	end)
end

function RoundServer._resetRound()
	playerKills = {}
	alivePlayers = {}
	extractedPlayers = {}
	airdropTriggered = false
	extractionActivated = false

	-- Reset sub-systems
	if ContainerServer then
		ContainerServer.resetContainers()
	end
	if AirdropServer then
		AirdropServer.reset()
	end
	if AIServer and AIServer.reset then
		AIServer.reset()
	end

	currentState = ROUND_STATE.Waiting
	fireStateChange(ROUND_STATE.Waiting)

	print("[CAG] Round reset — waiting for players")

	RoundServer._checkStart()
end

function RoundServer._checkStart()
	if currentState ~= ROUND_STATE.Waiting then
		return
	end

	local playerCount = #Players:GetPlayers()
	if playerCount >= Config.Round.MinPlayers then
		RoundServer._startRound()
	end
end

function RoundServer._startRound()
	if currentState ~= ROUND_STATE.Waiting then
		return
	end

	currentState = ROUND_STATE.Active
	matchStartTime = tick()
	matchDuration = Config.Round.MatchDuration
	roundActive = true
	fireStateChange(ROUND_STATE.Active)

	-- Mark all current players as alive
	for _, player in Players:GetPlayers() do
		alivePlayers[player] = true
		playerKills[player] = 0
	end

	-- Start AI waves
	if AIServer and AIServer.startWaves then
		AIServer.startWaves()
	end

	print("[CAG] Round started with " .. #Players:GetPlayers() .. " players")

	-- Match timer loop
	task.spawn(function()
		while roundActive do
			local elapsed = tick() - matchStartTime
			local remaining = math.max(0, matchDuration - elapsed)
			local progress = elapsed / matchDuration

			fireMatchTime(remaining)

			-- Trigger airdrop at 60%
			if not airdropTriggered and progress >= Config.Airdrop.TriggerPercent then
				airdropTriggered = true
				if AirdropServer then
					AirdropServer.triggerAirdrop()
				end
			end

			-- Activate extraction at 80%
			if not extractionActivated and progress >= Config.Round.ExtractionPhasePercent then
				extractionActivated = true
				currentState = ROUND_STATE.Extracting
				fireStateChange(ROUND_STATE.Extracting)

				if ExtractionServer and ExtractionServer.activate then
					ExtractionServer.activate()
				end

				print("[CAG] Extraction phase activated")
			end

			-- Broadcast leaderboard
			fireLeaderboardUpdate()

			-- Time expired
			if remaining <= 0 then
				endRound("time_expired")
				return
			end

			task.wait(1)
		end
	end)
end

-- ── Public API for other systems ─────────────────────────

function RoundServer.onPlayerKill(killer: Player, victimName: string)
	if not roundActive then
		return
	end

	playerKills[killer] = (playerKills[killer] or 0) + 1

	-- Fire kill feed entry
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remotes then
		local killFeedRemote = remotes:FindFirstChild(RemoteNames.KillFeedEntry)
		if killFeedRemote then
			killFeedRemote:FireAllClients({
				killer = killer.Name,
				victim = victimName,
				isAI = true,
			})
		end
	end

	fireLeaderboardUpdate()
end

function RoundServer.onPlayerDied(player: Player, killerName: string?)
	if not roundActive then
		return
	end

	alivePlayers[player] = nil

	-- Fire player eliminated to all
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remotes then
		local elimRemote = remotes:FindFirstChild(RemoteNames.PlayerEliminated)
		if elimRemote then
			elimRemote:FireAllClients({
				playerName = player.Name,
				killerName = killerName or "AI",
			})
		end

		-- Kill feed entry
		local killFeedRemote = remotes:FindFirstChild(RemoteNames.KillFeedEntry)
		if killFeedRemote then
			killFeedRemote:FireAllClients({
				killer = killerName or "AI",
				victim = player.Name,
				isAI = false,
			})
		end
	end

	fireLeaderboardUpdate()

	-- Check if all players dead
	if countAlivePlayers() == 0 then
		endRound("all_eliminated")
	end
end

function RoundServer.onPlayerExtracted(player: Player)
	if not roundActive then
		return
	end

	extractedPlayers[player] = true
	alivePlayers[player] = nil

	fireLeaderboardUpdate()

	-- Check if all players extracted or dead
	if countAlivePlayers() == 0 then
		endRound("all_extracted")
	end
end

function RoundServer.getRoundState(): string
	return currentState
end

function RoundServer.getCurrentMatchTime(): number
	if not roundActive then
		return 0
	end
	return math.max(0, matchDuration - (tick() - matchStartTime))
end

function RoundServer.isRoundActive(): boolean
	return roundActive
end

function RoundServer.getPlayerKills(player: Player): number
	return playerKills[player] or 0
end

-- ── Init ─────────────────────────────────────────────────

function RoundServer.init()
	local serverModules = script.Parent

	-- Resolve module references
	local pdModule = serverModules:FindFirstChild("PlayerDataServer")
	if pdModule then
		PlayerDataServer = require(pdModule)
	end
	local invModule = serverModules:FindFirstChild("InventoryServer")
	if invModule then
		InventoryServer = require(invModule)
	end
	local aiModule = serverModules:FindFirstChild("AIServer")
	if aiModule then
		AIServer = require(aiModule)
	end
	local extModule = serverModules:FindFirstChild("ExtractionServer")
	if extModule then
		ExtractionServer = require(extModule)
	end
	local airModule = serverModules:FindFirstChild("AirdropServer")
	if airModule then
		AirdropServer = require(airModule)
	end
	local contModule = serverModules:FindFirstChild("ContainerServer")
	if contModule then
		ContainerServer = require(contModule)
	end

	-- Set extraction callback
	if ExtractionServer then
		ExtractionServer.onPlayerExtracted = function(player)
			RoundServer.onPlayerExtracted(player)
		end
	end

	-- Listen for player ready (from main menu PLAY button)
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local readyRemote = remotes:WaitForChild(RemoteNames.PlayerReady)
	readyRemote.OnServerEvent:Connect(function(_player)
		RoundServer._checkStart()
	end)

	-- Listen for play again
	local playAgainRemote = remotes:WaitForChild(RemoteNames.PlayAgain)
	playAgainRemote.OnServerEvent:Connect(function(_player)
		RoundServer._checkStart()
	end)

	-- Track player deaths
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")
			humanoid.Died:Connect(function()
				if roundActive and alivePlayers[player] then
					RoundServer.onPlayerDied(player)
				end
			end)
		end)
	end)

	-- Also connect for players already in game
	for _, player in Players:GetPlayers() do
		if player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Died:Connect(function()
					if roundActive and alivePlayers[player] then
						RoundServer.onPlayerDied(player)
					end
				end)
			end
		end
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")
			humanoid.Died:Connect(function()
				if roundActive and alivePlayers[player] then
					RoundServer.onPlayerDied(player)
				end
			end)
		end)
	end

	-- Handle player leaving mid-round
	Players.PlayerRemoving:Connect(function(player)
		alivePlayers[player] = nil
		playerKills[player] = nil
		extractedPlayers[player] = nil
	end)

	-- Auto-start check when players join
	Players.PlayerAdded:Connect(function(_player)
		task.wait(2) -- give time for data to load
		RoundServer._checkStart()
	end)

	print("[CAG] RoundServer initialized")
end

return RoundServer
