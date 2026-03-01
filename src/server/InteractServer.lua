--[[
	InteractServer — server-side handler for the E-key interact system.
	Validates container interactions, rolls loot, manages container states.
	Container states: Ready / Looting / Looted
	Exports: resetContainers, getContainerState, init
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
local SERVER_RANGE = Config.Interact.SERVER_RANGE
local LOOT_LOCK_TIME = Config.Interact.LOOT_LOCK_TIME

local CONTAINER_STATE = { Ready = "Ready", Looting = "Looting", Looted = "Looted" }

-- Tracks state per container: [Instance] = { state, lootingPlayer? }
local containerStates = {}

local function initContainerState(container)
	if not containerStates[container] then
		containerStates[container] = {
			state = CONTAINER_STATE.Ready,
			lootingPlayer = nil,
		}
	end
end

local function getPlayerDistance(plr: Player, target: Instance): number?
	local character = plr.Character
	if not character then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end

	-- Find primary part or part of the target
	local targetPart = nil
	if target:IsA("Model") then
		targetPart = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
	elseif target:IsA("BasePart") then
		targetPart = target
	end

	if not targetPart then
		return nil
	end

	return (hrp.Position - targetPart.Position).Magnitude
end

local function handleInteract(plr: Player, container: Instance)
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

	-- Initialize state if needed
	initContainerState(container)
	local cState = containerStates[container]

	-- Validate not already looted or being looted
	if cState.state ~= CONTAINER_STATE.Ready then
		return
	end

	-- Server-side distance check (8 studs = 6 client + 2 tolerance)
	local dist = getPlayerDistance(plr, container)
	if not dist or dist > SERVER_RANGE then
		return
	end

	-- Check inventory space
	if InventoryServer then
		local inv = InventoryServer.getInventory(plr)
		if inv and #inv >= Config.Inventory.MaxVolatileSlots then
			local failRemote = remotes:FindFirstChild(RemoteNames.InteractFailed)
			if failRemote then
				failRemote:FireClient(plr, "INVENTORY_FULL")
			end
			return
		end
	end

	-- Lock container
	cState.state = CONTAINER_STATE.Looting
	cState.lootingPlayer = plr

	-- Roll loot and add to inventory
	if LootTableServer and InventoryServer then
		local item = LootTableServer.rollLoot("container", plr)
		if item then
			local added = InventoryServer.addItem(plr, item)
			if not added then
				-- Inventory became full between check and add
				local failRemote = remotes:FindFirstChild(RemoteNames.InteractFailed)
				if failRemote then
					failRemote:FireClient(plr, "INVENTORY_FULL")
				end
			end
		end
	end

	-- Fire container looted to all clients
	local lootedRemote = remotes:FindFirstChild(RemoteNames.ContainerLooted)
	if lootedRemote then
		lootedRemote:FireAllClients(container)
	end

	-- Unlock after lock time, then mark looted
	task.spawn(function()
		task.wait(LOOT_LOCK_TIME)
		cState.state = CONTAINER_STATE.Looted
		cState.lootingPlayer = nil
	end)
end

function InteractServer.resetContainers()
	-- Reset all tagged containers to Ready state
	for container, _ in containerStates do
		containerStates[container] = {
			state = CONTAINER_STATE.Ready,
			lootingPlayer = nil,
		}
	end

	-- Also init any tagged containers that may not have state yet
	for _, container in CollectionService:GetTagged(CONTAINER_TAG) do
		containerStates[container] = {
			state = CONTAINER_STATE.Ready,
			lootingPlayer = nil,
		}
	end

	print("[CAG] InteractServer: containers reset")
end

function InteractServer.getContainerState(container: Instance): string?
	local cState = containerStates[container]
	if not cState then
		return nil
	end
	return cState.state
end

function InteractServer.init()
	local serverModules = script.Parent
	local lootModule = serverModules:FindFirstChild("LootTableServer")
	if lootModule then
		LootTableServer = require(lootModule)
	end
	local invModule = serverModules:FindFirstChild("InventoryServer")
	if invModule then
		InventoryServer = require(invModule)
	end

	-- Init state for all currently tagged containers
	for _, container in CollectionService:GetTagged(CONTAINER_TAG) do
		initContainerState(container)
	end

	-- Watch for newly tagged containers
	CollectionService:GetInstanceAddedSignal(CONTAINER_TAG):Connect(function(container)
		initContainerState(container)
	end)

	-- Clean up removed containers
	CollectionService:GetInstanceRemovedSignal(CONTAINER_TAG):Connect(function(container)
		containerStates[container] = nil
	end)

	-- Listen for ContainerInteract from clients
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local interactRemote = remotes:WaitForChild(RemoteNames.ContainerInteract)

	interactRemote.OnServerEvent:Connect(function(plr, container)
		handleInteract(plr, container)
	end)

	print("[CAG] InteractServer initialized")
end

return InteractServer
