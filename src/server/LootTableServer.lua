--[[
	LootTableServer — rolls loot from weighted rarity tables.
	Sources: container (Common-heavy), ai_drop (Uncommon-heavy, 40% chance),
	airdrop (Rare+ only).
	Exports: rollLoot, getLootTable
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)
local LootTableData = require(ReplicatedStorage.Shared.LootTableData)

local LootTableServer = {}

-- Index items by rarity for fast lookup
local itemsByRarity = {}

local function buildRarityIndex()
	itemsByRarity = {
		Common = {},
		Uncommon = {},
		Rare = {},
		Epic = {},
		Legendary = {},
	}

	for _, item in LootTableData do
		local rarityList = itemsByRarity[item.rarity]
		if rarityList then
			table.insert(rarityList, item)
		end
	end
end

local function rollRarity(weights: { [string]: number }): string
	local totalWeight = 0
	for _, w in weights do
		totalWeight = totalWeight + w
	end

	local roll = math.random() * totalWeight
	local cumulative = 0

	-- Sort keys for deterministic order
	local sortedRarities = {}
	for rarity, _ in weights do
		table.insert(sortedRarities, rarity)
	end
	table.sort(sortedRarities)

	for _, rarity in sortedRarities do
		cumulative = cumulative + weights[rarity]
		if roll <= cumulative then
			return rarity
		end
	end

	return "Common"
end

local function pickRandomItem(rarity: string)
	local pool = itemsByRarity[rarity]
	if not pool or #pool == 0 then
		-- Fallback: try Common
		pool = itemsByRarity["Common"]
		if not pool or #pool == 0 then
			return nil
		end
	end
	return pool[math.random(1, #pool)]
end

function LootTableServer.rollLoot(source: string, player: Player?)
	local weights

	if source == "container" then
		weights = Config.Loot.ContainerWeights
	elseif source == "ai_drop" then
		-- Check drop chance first
		if math.random() > Config.Loot.AIDropChance then
			return nil -- no drop
		end
		weights = Config.Loot.AIDropWeights
	elseif source == "airdrop" then
		weights = Config.Loot.AirdropWeights
	else
		weights = Config.Loot.ContainerWeights
	end

	local rarity = rollRarity(weights)
	local item = pickRandomItem(rarity)

	if item and player then
		-- Fire LootReceived to the player who got the loot
		local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
		if remotes then
			local lootRemote = remotes:FindFirstChild(RemoteNames.LootReceived)
			if lootRemote then
				lootRemote:FireClient(player, {
					id = item.id,
					name = item.name,
					rarity = item.rarity,
					type = item.type,
					value = item.value,
				})
			end
		end
	end

	return item
end

function LootTableServer.getLootTable()
	return LootTableData
end

function LootTableServer.init()
	buildRarityIndex()

	-- Log item pool size
	local total = 0
	for rarity, items in itemsByRarity do
		total = total + #items
	end
	print("[CAG] LootTableServer initialized (" .. total .. " items in pool)")
end

return LootTableServer
