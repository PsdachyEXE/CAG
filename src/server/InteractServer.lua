--[[
	InteractServer — server-side container interact handler.
	Tags models named ContainerLarge/Medium/Small with CollectionService "LootContainer".
	Containers hold rolled loot arrays. On interact, sends InventoryState to client
	with container contents + player inventory. Handles ContainerTakeItem for
	individual item transfers.
	Container states: Ready / Open / Empty
	Exports: resetContainers, init
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local InteractServer = {}

-- Module references (set during init)
local LootTableServer = nil
local InventoryServer = nil

local CONTAINER_TAG = "LootContainer"
local SERVER_RANGE = 8 -- 6 client + 2 tolerance

local VALID_NAMES = {
	ContainerLarge = true,
	ContainerMedium = true,
	ContainerSmall = true,
}

-- Container state tracking: [Instance] = { state, items = {}, openBy? }
local containerStates = {}

-- Track which container each player currently has open
local playerOpenContainer = {} -- [Player] = containerInstance

local function tagObject(obj)
	if VALID_NAMES[obj.Name] then
		if not CollectionService:HasTag(obj, CONTAINER_TAG) then
			CollectionService:AddTag(obj, CONTAINER_TAG)
		end
	end
end

local function rollContainerContents(container)
	if not LootTableServer then
		return {}
	end

	local rollConfig = Config.CONTAINER_ROLLS[container.Name]
	if not rollConfig then
		rollConfig = { min = 2, max = 4 }
	end

	local count = math.random(rollConfig.min, rollConfig.max)
	local items = {}
	for _ = 1, count do
		local item = LootTableServer.rollLoot("container")
		if item then
			table.insert(items, item)
		end
	end

	return items
end

local function initState(container)
	if not containerStates[container] then
		containerStates[container] = { state = "Ready", items = {} }
	end
end

local function getDistance(player: Player, target: Instance): number?
	local character = player.Character
	if not character then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end

	local part = nil
	if target:IsA("Model") then
		part = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
	elseif target:IsA("BasePart") then
		part = target
	end

	if not part then
		return nil
	end

	return (hrp.Position - part.Position).Magnitude
end

local function sendInventoryState(player, container)
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remotes then
		return
	end

	local stateRemote = remotes:FindFirstChild(RemoteNames.InventoryState)
	if not stateRemote then
		return
	end

	local cState = containerStates[container]
	local containerItems = (cState and cState.items) or {}
	local playerItems = {}
	if InventoryServer then
		playerItems = InventoryServer.getInventory(player)
	end

	stateRemote:FireClient(player, {
		container = container,
		containerItems = containerItems,
		playerItems = playerItems,
	})
end

local function handleInteract(player: Player, container: Instance)
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remotes then
		return
	end

	-- Validate container exists and is tagged
	if not container or not container.Parent then
		return
	end
	if not CollectionService:HasTag(container, CONTAINER_TAG) then
		return
	end

	-- Init state if needed
	initState(container)
	local cState = containerStates[container]

	-- Can only open Ready or already-Open containers
	if cState.state == "Empty" then
		return
	end

	-- Distance check
	local dist = getDistance(player, container)
	if not dist or dist > SERVER_RANGE then
		return
	end

	-- If Ready, roll contents on first open
	if cState.state == "Ready" then
		cState.items = rollContainerContents(container)
		cState.state = "Open"
	end

	-- Track which container this player has open
	playerOpenContainer[player] = container

	-- Send full state to client (container contents + player inventory)
	sendInventoryState(player, container)
end

local function handleTakeItem(player: Player, container: Instance, itemIndex: number)
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remotes then
		return
	end

	-- Validate container
	if not container or not container.Parent then
		return
	end
	if not CollectionService:HasTag(container, CONTAINER_TAG) then
		return
	end

	initState(container)
	local cState = containerStates[container]

	-- Must be Open
	if cState.state ~= "Open" then
		return
	end

	-- Distance check
	local dist = getDistance(player, container)
	if not dist or dist > SERVER_RANGE then
		return
	end

	-- Validate item index
	if type(itemIndex) ~= "number" then
		return
	end
	itemIndex = math.floor(itemIndex)
	if itemIndex < 1 or itemIndex > #cState.items then
		return
	end

	local item = cState.items[itemIndex]
	if not item then
		return
	end

	-- Inventory full check
	if InventoryServer and InventoryServer.isFull(player) then
		local failRemote = remotes:FindFirstChild(RemoteNames.InteractFailed)
		if failRemote then
			failRemote:FireClient(player, "INVENTORY_FULL")
		end
		return
	end

	-- Add to player inventory
	if InventoryServer then
		local added = InventoryServer.addItem(player, item)
		if not added then
			local failRemote = remotes:FindFirstChild(RemoteNames.InteractFailed)
			if failRemote then
				failRemote:FireClient(player, "INVENTORY_FULL")
			end
			return
		end
	end

	-- Remove from container
	table.remove(cState.items, itemIndex)

	-- If container is now empty, mark it
	if #cState.items == 0 then
		cState.state = "Empty"
	end

	-- Send updated state back to client
	local transferRemote = remotes:FindFirstChild(RemoteNames.ItemTransferred)
	if transferRemote then
		local playerItems = {}
		if InventoryServer then
			playerItems = InventoryServer.getInventory(player)
		end
		transferRemote:FireClient(player, {
			container = container,
			containerItems = cState.items,
			playerItems = playerItems,
			takenItem = item,
		})
	end
end

function InteractServer.resetContainers()
	for container, _ in containerStates do
		containerStates[container] = { state = "Ready", items = {} }
	end

	for _, container in CollectionService:GetTagged(CONTAINER_TAG) do
		containerStates[container] = { state = "Ready", items = {} }
	end

	-- Clear all player open-container refs
	table.clear(playerOpenContainer)

	print("[CAG] InteractServer: containers reset to Ready")
end

function InteractServer.init()
	-- Resolve module references
	local serverModules = script.Parent
	local lootMod = serverModules:FindFirstChild("LootTableServer")
	if lootMod then
		LootTableServer = require(lootMod)
	end
	local invMod = serverModules:FindFirstChild("InventoryServer")
	if invMod then
		InventoryServer = require(invMod)
	end

	-- Tag all existing valid containers in Workspace
	for _, obj in workspace:GetDescendants() do
		tagObject(obj)
	end

	-- Warn about any containers that are still untagged after auto-tagging.
	-- This catches naming mismatches or containers added through unusual paths.
	for _, model in workspace:GetDescendants() do
		if (model.Name == "ContainerMedium" or
			model.Name == "ContainerLarge" or
			model.Name == "ContainerSmall") and
			not CollectionService:HasTag(model, CONTAINER_TAG) then
			warn("CAG: Untagged container found: " .. model:GetFullName())
		end
	end

	-- Watch for new objects
	workspace.DescendantAdded:Connect(function(obj)
		tagObject(obj)
	end)

	-- Init state for all tagged containers
	for _, container in CollectionService:GetTagged(CONTAINER_TAG) do
		initState(container)
	end

	-- Track newly tagged
	CollectionService:GetInstanceAddedSignal(CONTAINER_TAG):Connect(function(container)
		initState(container)
	end)

	-- Clean up removed
	CollectionService:GetInstanceRemovedSignal(CONTAINER_TAG):Connect(function(container)
		containerStates[container] = nil
	end)

	-- Clean up player leaving
	Players.PlayerRemoving:Connect(function(player)
		playerOpenContainer[player] = nil
	end)

	-- Listen for ContainerInteract remote (E key)
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local interactRemote = remotes:WaitForChild(RemoteNames.ContainerInteract)

	interactRemote.OnServerEvent:Connect(function(player, container)
		task.spawn(function()
			handleInteract(player, container)
		end)
	end)

	-- Listen for ContainerTakeItem remote (click item in container panel)
	local takeRemote = remotes:WaitForChild(RemoteNames.ContainerTakeItem)

	takeRemote.OnServerEvent:Connect(function(player, container, itemIndex)
		task.spawn(function()
			handleTakeItem(player, container, itemIndex)
		end)
	end)

	local tagCount = #CollectionService:GetTagged(CONTAINER_TAG)
	print("[CAG] InteractServer initialized (" .. tagCount .. " containers tagged)")
end

return InteractServer
