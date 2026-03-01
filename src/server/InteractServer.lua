--[[
	InteractServer — server-side container interact handler.
	On startup: tags all models named ContainerLarge, ContainerMedium,
	ContainerSmall with CollectionService "LootContainer".
	Listens for ContainerInteract remote, validates, rolls loot.
	Container states: Ready / Looting / Looted
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
local LOOT_DELAY = Config.CONTAINER_LOOT_DELAY

local VALID_NAMES = {
	ContainerLarge = true,
	ContainerMedium = true,
	ContainerSmall = true,
}

-- Container state tracking: [Instance] = { state, lootingPlayer? }
local containerStates = {} -- Ready / Looting / Looted

local function tagObject(obj)
	if VALID_NAMES[obj.Name] then
		if not CollectionService:HasTag(obj, CONTAINER_TAG) then
			CollectionService:AddTag(obj, CONTAINER_TAG)
		end
	end
end

local function initState(container)
	if not containerStates[container] then
		containerStates[container] = { state = "Ready" }
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

	-- Must be Ready
	if cState.state ~= "Ready" then
		return
	end

	-- Distance check
	local dist = getDistance(player, container)
	if not dist or dist > SERVER_RANGE then
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

	-- Lock container
	cState.state = "Looting"
	cState.lootingPlayer = player

	-- Loot delay
	task.wait(LOOT_DELAY)

	-- Roll loot
	local item = nil
	if LootTableServer then
		item = LootTableServer.rollLoot("container")
	end

	-- Add to inventory
	if item and InventoryServer then
		local added = InventoryServer.addItem(player, item)
		if added then
			-- Fire LootReceived to client with item data
			local lootRemote = remotes:FindFirstChild(RemoteNames.LootReceived)
			if lootRemote then
				lootRemote:FireClient(player, item)
			end
		else
			-- Became full between check and add
			local failRemote = remotes:FindFirstChild(RemoteNames.InteractFailed)
			if failRemote then
				failRemote:FireClient(player, "INVENTORY_FULL")
			end
		end
	end

	-- Mark looted
	cState.state = "Looted"
	cState.lootingPlayer = nil
end

function InteractServer.resetContainers()
	for container, _ in containerStates do
		containerStates[container] = { state = "Ready" }
	end

	for _, container in CollectionService:GetTagged(CONTAINER_TAG) do
		containerStates[container] = { state = "Ready" }
	end

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

	-- Listen for ContainerInteract remote
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local interactRemote = remotes:WaitForChild(RemoteNames.ContainerInteract)

	interactRemote.OnServerEvent:Connect(function(player, container)
		task.spawn(function()
			handleInteract(player, container)
		end)
	end)

	local tagCount = #CollectionService:GetTagged(CONTAINER_TAG)
	print("[CAG] InteractServer initialized (" .. tagCount .. " containers tagged)")
end

return InteractServer
