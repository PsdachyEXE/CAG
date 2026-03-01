--[[
	InventoryServer — volatile inventory system.
	Items are lost on death, kept on extraction.
	Max 4 volatile slots per player.
	Exports: addItem, getInventory, wipeVolatile, calculateExtractionBonus, getItemNames
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local InventoryServer = {}

local volatileInventories = {} -- [player] = { items = {} }

function InventoryServer.addItem(player: Player, item): boolean
	local inv = volatileInventories[player]
	if not inv then
		return false
	end

	if #inv.items >= Config.Inventory.MaxVolatileSlots then
		return false -- inventory full
	end

	table.insert(inv.items, {
		itemID = item.id,
		name = item.name,
		rarity = item.rarity,
		type = item.type,
		value = item.value or 0,
	})

	-- Notify client of updated inventory
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remotes then
		local updateRemote = remotes:FindFirstChild(RemoteNames.InventoryUpdate)
		if updateRemote then
			updateRemote:FireClient(player, inv.items)
		end
	end

	return true
end

function InventoryServer.getInventory(player: Player)
	local inv = volatileInventories[player]
	if not inv then
		return {}
	end
	return inv.items
end

function InventoryServer.wipeVolatile(player: Player)
	local inv = volatileInventories[player]
	if not inv then
		return
	end
	inv.items = {}

	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remotes then
		local updateRemote = remotes:FindFirstChild(RemoteNames.InventoryUpdate)
		if updateRemote then
			updateRemote:FireClient(player, {})
		end
	end
end

function InventoryServer.calculateExtractionBonus(player: Player): number
	local inv = volatileInventories[player]
	if not inv then
		return 0
	end

	local totalValue = 0
	for _, item in inv.items do
		totalValue = totalValue + (item.value or 0)
	end
	return totalValue
end

function InventoryServer.getItemNames(player: Player): { string }
	local inv = volatileInventories[player]
	if not inv then
		return {}
	end

	local names = {}
	for _, item in inv.items do
		table.insert(names, item.name)
	end
	return names
end

function InventoryServer.init()
	Players.PlayerAdded:Connect(function(player)
		volatileInventories[player] = { items = {} }
	end)

	-- Init for players already in game
	for _, player in Players:GetPlayers() do
		if not volatileInventories[player] then
			volatileInventories[player] = { items = {} }
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		volatileInventories[player] = nil
	end)

	print("[CAG] InventoryServer initialized")
end

return InventoryServer
