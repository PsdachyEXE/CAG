--[[
	ProgressionServer — handles level-up reward distribution.
	Sits on top of PlayerDataServer. When a player levels up, checks
	ProgressionData for unlocks at that level and grants rewards
	(weapons, cosmetics, currency). Fires notifications to client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)
local ProgressionData = require(ReplicatedStorage.Shared.ProgressionData)

local ProgressionServer = {}

-- Populated during init
local PlayerDataServer = nil

-- Build a level → unlocks lookup for fast queries
local unlocksByLevel = {} -- [level] = { {unlock}, {unlock}, ... }

local function buildUnlockIndex()
	for _, entry in ProgressionData do
		local lvl = entry.level
		if not unlocksByLevel[lvl] then
			unlocksByLevel[lvl] = {}
		end
		table.insert(unlocksByLevel[lvl], entry)
	end
end

--- Returns all unlocks at the given level (or empty table).
function ProgressionServer.getUnlocksAtLevel(level: number): { any }
	return unlocksByLevel[level] or {}
end

--- Check and grant rewards for a specific level.
--- Called when a player reaches a new level.
function ProgressionServer.grantLevelRewards(player: Player, level: number)
	if not PlayerDataServer then
		return
	end

	local unlocks = unlocksByLevel[level]
	if not unlocks or #unlocks == 0 then
		return
	end

	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")

	for _, unlock in unlocks do
		local rewardType = unlock.type
		local rewardID = unlock.id
		local displayName = unlock.displayName

		if rewardType == "weapon" then
			PlayerDataServer.unlockWeapon(player, rewardID)
			if remotes then
				local notifRemote = remotes:FindFirstChild(RemoteNames.ShowNotification)
				if notifRemote then
					notifRemote:FireClient(player, {
						type = "loot",
						text = "Weapon Unlocked!",
						subText = displayName,
					})
				end
			end

		elseif rewardType == "cosmetic" then
			-- Add cosmetic to player data
			local data = PlayerDataServer.getData(player)
			if data then
				if not data.cosmetics then
					data.cosmetics = {}
				end
				local alreadyHas = false
				for _, id in data.cosmetics do
					if id == rewardID then
						alreadyHas = true
						break
					end
				end
				if not alreadyHas then
					table.insert(data.cosmetics, rewardID)
				end
			end
			if remotes then
				local notifRemote = remotes:FindFirstChild(RemoteNames.ShowNotification)
				if notifRemote then
					notifRemote:FireClient(player, {
						type = "loot",
						text = "Cosmetic Unlocked!",
						subText = displayName,
					})
				end
			end

		elseif rewardType == "currency" then
			local amount = unlock.amount or 0
			if amount > 0 then
				PlayerDataServer.addCurrency(player, amount)
			end
			if remotes then
				local notifRemote = remotes:FindFirstChild(RemoteNames.ShowNotification)
				if notifRemote then
					notifRemote:FireClient(player, {
						type = "xp",
						text = "Credits Earned!",
						subText = displayName,
					})
				end
			end

		elseif rewardType == "feature" then
			-- Feature unlocks are stored as flags in player data
			local data = PlayerDataServer.getData(player)
			if data then
				if not data.features then
					data.features = {}
				end
				data.features[rewardID] = true
			end
			if remotes then
				local notifRemote = remotes:FindFirstChild(RemoteNames.ShowNotification)
				if notifRemote then
					notifRemote:FireClient(player, {
						type = "info",
						text = "Feature Unlocked!",
						subText = displayName,
					})
				end
			end
		end

		print("[CAG] " .. player.Name .. " unlocked: " .. displayName .. " (Level " .. level .. ")")
	end
end

--- Checks a player's current level for any rewards they should have
--- but haven't been granted yet (catch-up for returning players).
function ProgressionServer.reconcileUnlocks(player: Player)
	if not PlayerDataServer then
		return
	end

	local data = PlayerDataServer.getData(player)
	if not data then
		return
	end

	local playerLevel = data.level

	for level, unlocks in unlocksByLevel do
		if level <= playerLevel then
			for _, unlock in unlocks do
				local rewardType = unlock.type
				local rewardID = unlock.id

				if rewardType == "weapon" then
					-- Check if already has it
					local has = false
					for _, wID in data.unlockedWeapons or {} do
						if wID == rewardID then
							has = true
							break
						end
					end
					if not has then
						PlayerDataServer.unlockWeapon(player, rewardID)
					end

				elseif rewardType == "cosmetic" then
					if not data.cosmetics then
						data.cosmetics = {}
					end
					local has = false
					for _, cID in data.cosmetics do
						if cID == rewardID then
							has = true
							break
						end
					end
					if not has then
						table.insert(data.cosmetics, rewardID)
					end

				elseif rewardType == "feature" then
					if not data.features then
						data.features = {}
					end
					if not data.features[rewardID] then
						data.features[rewardID] = true
					end

				-- Currency rewards are one-time grants; skip on reconcile
				-- to avoid double-granting
				end
			end
		end
	end
end

--- Returns whether a player has a specific feature unlocked.
function ProgressionServer.hasFeature(player: Player, featureID: string): boolean
	if not PlayerDataServer then
		return false
	end

	local data = PlayerDataServer.getData(player)
	if not data then
		return false
	end

	return data.features and data.features[featureID] == true
end

--- Returns the full list of unlock milestones (for UI display).
function ProgressionServer.getAllMilestones()
	return ProgressionData
end

function ProgressionServer.init()
	buildUnlockIndex()

	-- Get reference to PlayerDataServer
	local serverScript = script.Parent
	local success, result = pcall(function()
		return require(serverScript.PlayerDataServer)
	end)

	if success then
		PlayerDataServer = result
	else
		warn("[CAG] ProgressionServer: Could not find PlayerDataServer: " .. tostring(result))
	end

	-- Hook into LevelUp remote to grant rewards when players level up
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local levelUpRemote = remotes:WaitForChild(RemoteNames.LevelUp)

	-- We can't directly hook the server-side fire, so we wrap PlayerDataServer.addXP
	-- to catch level-ups. Instead, use a post-level-up check approach.
	-- The cleanest way: patch addXP to call us after a level up.
	if PlayerDataServer then
		local originalAddXP = PlayerDataServer.addXP

		PlayerDataServer.addXP = function(player: Player, amount: number)
			local data = PlayerDataServer.getData(player)
			local prevLevel = data and data.level or 1

			local leveledUp = originalAddXP(player, amount)

			if leveledUp and data then
				local newLevel = data.level
				-- Grant rewards for each level gained
				for lvl = prevLevel + 1, newLevel do
					ProgressionServer.grantLevelRewards(player, lvl)
				end
			end

			return leveledUp
		end
	end

	-- Reconcile unlocks for players already in game
	local Players = game:GetService("Players")
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			-- Wait a moment for PlayerDataServer to finish loading
			task.wait(2)
			ProgressionServer.reconcileUnlocks(player)
		end)
	end

	-- Reconcile for new players
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			-- Wait for data to load
			task.wait(3)
			ProgressionServer.reconcileUnlocks(player)
		end)
	end)

	print("[CAG] ProgressionServer initialized (" .. #ProgressionData .. " milestones)")
end

return ProgressionServer
