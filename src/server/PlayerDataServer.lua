--[[
	PlayerDataServer — persistent player data using DataStoreService.
	Implements ProfileService pattern manually (session locking, retry logic).
	Auto-saves on round end, player leaving, and periodic interval.
	Exports: getData, addXP, addCurrency, unlockWeapon, save, getXPToNextLevel
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local PlayerDataServer = {}

local DATA_STORE_NAME = "CAG_PlayerData_v1"
local SESSION_KEY_PREFIX = "SessionLock_"
local AUTO_SAVE_INTERVAL = 60
local MAX_RETRIES = 3

local dataStore = nil
local sessionStore = nil
local playerProfiles = {} -- [player] = { data = {}, dirty = false }

local DEFAULT_DATA = {
	level = 1,
	xp = 0,
	totalMatches = 0,
	totalExtractions = 0,
	currency = 0,
	unlockedWeapons = {},
	equippedWeapon = "wpn_default",
	cosmetics = {},
	equippedCosmetic = "",
}

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function reconcileData(saved)
	local data = deepCopy(DEFAULT_DATA)
	if saved and type(saved) == "table" then
		for key, _ in pairs(DEFAULT_DATA) do
			if saved[key] ~= nil then
				data[key] = saved[key]
			end
		end
	end
	return data
end

local function xpToNextLevel(level: number): number
	return math.floor(Config.Progression.XPCurveBase * level ^ Config.Progression.XPCurveExponent)
end

local function retryAsync(fn, ...)
	local args = { ... }
	local success, result
	for attempt = 1, MAX_RETRIES do
		success, result = pcall(function()
			return fn(table.unpack(args))
		end)
		if success then
			return true, result
		end
		if attempt < MAX_RETRIES then
			task.wait(attempt) -- exponential-ish backoff
		end
	end
	return false, result
end

-- Session locking: claim this player's data for this server
local function acquireSessionLock(userId: number): boolean
	if not sessionStore then
		return true
	end

	local lockKey = SESSION_KEY_PREFIX .. userId
	local serverJobId = game.JobId

	local success, _ = retryAsync(function()
		return sessionStore:UpdateAsync(lockKey, function(old)
			if old == nil or old == "" or old == serverJobId then
				return serverJobId
			end
			-- Another server holds the lock — check if stale (>10 min)
			return serverJobId -- Force claim for now (simplified)
		end)
	end)

	return success
end

local function releaseSessionLock(userId: number)
	if not sessionStore then
		return
	end

	local lockKey = SESSION_KEY_PREFIX .. userId
	pcall(function()
		sessionStore:RemoveAsync(lockKey)
	end)
end

local function loadData(player: Player): boolean
	local key = "Player_" .. player.UserId

	-- Acquire session lock
	if not acquireSessionLock(player.UserId) then
		warn("[CAG] Failed to acquire session lock for " .. player.Name)
	end

	local success, result = retryAsync(function()
		return dataStore:GetAsync(key)
	end)

	if not success then
		warn("[CAG] Failed to load data for " .. player.Name .. ": " .. tostring(result))
		return false
	end

	local data = reconcileData(result)
	playerProfiles[player] = {
		data = data,
		dirty = false,
	}

	return true
end

local function saveData(player: Player): boolean
	local profile = playerProfiles[player]
	if not profile then
		return false
	end

	local key = "Player_" .. player.UserId

	local success, err = retryAsync(function()
		dataStore:SetAsync(key, profile.data)
	end)

	if not success then
		warn("[CAG] Failed to save data for " .. player.Name .. ": " .. tostring(err))
		return false
	end

	profile.dirty = false
	return true
end

function PlayerDataServer.getData(player: Player)
	local profile = playerProfiles[player]
	if not profile then
		return nil
	end
	return profile.data
end

function PlayerDataServer.addXP(player: Player, amount: number)
	local profile = playerProfiles[player]
	if not profile then
		return
	end

	local data = profile.data
	data.xp = data.xp + amount
	profile.dirty = true

	local leveledUp = false

	-- Check level ups
	local required = xpToNextLevel(data.level)
	while data.xp >= required and data.level < Config.Progression.LevelCap do
		data.xp = data.xp - required
		data.level = data.level + 1
		required = xpToNextLevel(data.level)
		leveledUp = true

		-- Fire level up remote
		local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
		if remotes then
			local levelUpRemote = remotes:FindFirstChild(RemoteNames.LevelUp)
			if levelUpRemote then
				levelUpRemote:FireClient(player, data.level)
			end
		end
	end

	-- Fire XP gained remote
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remotes then
		local xpRemote = remotes:FindFirstChild(RemoteNames.XPGained)
		if xpRemote then
			xpRemote:FireClient(player, amount, data.xp, xpToNextLevel(data.level))
		end
	end

	return leveledUp
end

function PlayerDataServer.addCurrency(player: Player, amount: number)
	local profile = playerProfiles[player]
	if not profile then
		return
	end
	profile.data.currency = profile.data.currency + amount
	profile.dirty = true
end

function PlayerDataServer.unlockWeapon(player: Player, weaponID: string)
	local profile = playerProfiles[player]
	if not profile then
		return
	end

	local weapons = profile.data.unlockedWeapons
	for _, id in weapons do
		if id == weaponID then
			return
		end -- already unlocked
	end
	table.insert(weapons, weaponID)
	profile.dirty = true
end

function PlayerDataServer.save(player: Player): boolean
	return saveData(player)
end

function PlayerDataServer.getXPToNextLevel(level: number): number
	return xpToNextLevel(level)
end

function PlayerDataServer.init()
	-- Initialize DataStores
	local storeSuccess, storeErr = pcall(function()
		dataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
		sessionStore = DataStoreService:GetDataStore(DATA_STORE_NAME .. "_Sessions")
	end)

	if not storeSuccess then
		warn("[CAG] DataStore unavailable (Studio?): " .. tostring(storeErr))
		-- Create a mock for Studio testing
		dataStore = {
			GetAsync = function() return nil end,
			SetAsync = function() end,
			RemoveAsync = function() end,
			UpdateAsync = function(_, _, fn) return fn(nil) end,
		}
		sessionStore = nil
	end

	-- Load data for players already in game
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			local loaded = loadData(player)
			if not loaded then
				playerProfiles[player] = {
					data = deepCopy(DEFAULT_DATA),
					dirty = false,
				}
			end
			print("[CAG] Data loaded for " .. player.Name .. " (Lv." .. playerProfiles[player].data.level .. ")")
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			local loaded = loadData(player)
			if not loaded then
				playerProfiles[player] = {
					data = deepCopy(DEFAULT_DATA),
					dirty = false,
				}
			end
			print("[CAG] Data loaded for " .. player.Name .. " (Lv." .. playerProfiles[player].data.level .. ")")
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if playerProfiles[player] then
			saveData(player)
			releaseSessionLock(player.UserId)
			playerProfiles[player] = nil
		end
	end)

	-- Auto-save dirty profiles periodically
	task.spawn(function()
		while true do
			task.wait(AUTO_SAVE_INTERVAL)
			for player, profile in playerProfiles do
				if profile.dirty and player.Parent then
					task.spawn(function()
						saveData(player)
					end)
				end
			end
		end
	end)

	-- Save all on server shutdown
	game:BindToClose(function()
		for player, _ in playerProfiles do
			saveData(player)
			releaseSessionLock(player.UserId)
		end
	end)

	print("[CAG] PlayerDataServer initialized")
end

return PlayerDataServer
