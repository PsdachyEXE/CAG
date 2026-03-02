--[[
	InventoryServer — per-player volatile inventory.
	Max slots defined by Config.MAX_INVENTORY_SLOTS (16).
	No DataStore — server-side table only.
	Exports: addItem, getInventory, isFull, removeItem, wipeInventory, init
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local InventoryServer = {}

local inventories = {} -- [player] = { items = {} }

function InventoryServer.addItem(player: Player, item): boolean
	local inv = inventories[player]
	if not inv then
		return false
	end

	if #inv.items >= Config.MAX_INVENTORY_SLOTS then
		return false
	end

	table.insert(inv.items, {
		id = item.id,
		name = item.name,
		type = item.type,
		rarity = item.rarity,
		value = item.value or 0,
		icon = item.icon,
		isWeapon = item.isWeapon or false,
		category = item.category,
		groundModel = item.groundModel,
		handModel = item.handModel,
	})

	return true
end

function InventoryServer.removeItem(player: Player, index: number): boolean
	local inv = inventories[player]
	if not inv then
		return false
	end

	if index < 1 or index > #inv.items then
		return false
	end

	table.remove(inv.items, index)
	return true
end

function InventoryServer.getInventory(player: Player)
	local inv = inventories[player]
	if not inv then
		return {}
	end
	return inv.items
end

function InventoryServer.isFull(player: Player): boolean
	local inv = inventories[player]
	if not inv then
		return true
	end
	return #inv.items >= Config.MAX_INVENTORY_SLOTS
end

function InventoryServer.wipeInventory(player: Player)
	local inv = inventories[player]
	if inv then
		inv.items = {}
	end
end

function InventoryServer.init()
	Players.PlayerAdded:Connect(function(player)
		inventories[player] = { items = {} }
	end)

	for _, player in Players:GetPlayers() do
		if not inventories[player] then
			inventories[player] = { items = {} }
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
	end)

	print("[CAG] InventoryServer initialized (max " .. Config.MAX_INVENTORY_SLOTS .. " slots)")
end

return InventoryServer
