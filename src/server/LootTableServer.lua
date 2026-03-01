--[[
	LootTableServer — rolls loot from LootTableData with weighted rarity.
	Source "container" uses: Common 60%, Uncommon 30%, Rare 8%, Epic 2%
	Exports: rollLoot(source)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LootTableData = require(ReplicatedStorage.Shared.LootTableData)

local LootTableServer = {}

-- Index items by rarity for fast lookup
local itemsByRarity = {}

local SOURCE_WEIGHTS = {
	container = { Common = 60, Uncommon = 30, Rare = 8, Epic = 2 },
}

local function buildIndex()
	itemsByRarity = {}
	for _, item in LootTableData do
		if not itemsByRarity[item.rarity] then
			itemsByRarity[item.rarity] = {}
		end
		table.insert(itemsByRarity[item.rarity], item)
	end
end

local function rollRarity(weights: { [string]: number }): string
	local total = 0
	for _, w in weights do
		total = total + w
	end

	local roll = math.random() * total
	local cumulative = 0

	-- Sort keys for deterministic order
	local sorted = {}
	for rarity, _ in weights do
		table.insert(sorted, rarity)
	end
	table.sort(sorted)

	for _, rarity in sorted do
		cumulative = cumulative + weights[rarity]
		if roll <= cumulative then
			return rarity
		end
	end

	return "Common"
end

function LootTableServer.rollLoot(source: string)
	local weights = SOURCE_WEIGHTS[source] or SOURCE_WEIGHTS.container

	local rarity = rollRarity(weights)
	local pool = itemsByRarity[rarity]

	if not pool or #pool == 0 then
		pool = itemsByRarity["Common"]
		if not pool or #pool == 0 then
			return nil
		end
	end

	local item = pool[math.random(1, #pool)]

	-- Return a copy
	return {
		id = item.id,
		name = item.name,
		type = item.type,
		rarity = item.rarity,
		value = item.value,
	}
end

function LootTableServer.init()
	buildIndex()

	local total = 0
	for _, items in itemsByRarity do
		total = total + #items
	end
	print("[CAG] LootTableServer initialized (" .. total .. " items)")
end

return LootTableServer
