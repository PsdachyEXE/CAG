--[[
	ContainerServer — manages loot containers placed around the map.
	Responsibilities:
	  - Tags Workspace containers with CollectionService "LootContainer"
	  - Spawns programmatic containers at fixed positions (demo mode)
	  - Resets containers on round start
	  - stop/start for demo mode toggle
	Loot rolling and interaction handled by InteractServer.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local ContainerServer = {}

local CONTAINER_TAG = "LootContainer"

-- Valid container names that get tagged in Workspace
local VALID_CONTAINER_NAMES = {
	ContainerLarge = true,
	ContainerMedium = true,
	ContainerSmall = true,
}

-- Programmatic container tracking (demo mode containers)
local spawnedContainers = {} -- [part] = true
local CONTAINER_POSITIONS = {
	Vector3.new(20, 1, 20),
	Vector3.new(-20, 1, 20),
	Vector3.new(20, 1, -20),
	Vector3.new(-20, 1, -20),
	Vector3.new(40, 1, 0),
	Vector3.new(-40, 1, 0),
	Vector3.new(0, 1, 40),
	Vector3.new(0, 1, -40),
	Vector3.new(30, 1, 30),
	Vector3.new(-30, 1, -30),
}

local function createProgrammaticContainer(position: Vector3)
	local part = Instance.new("Part")
	part.Name = "ContainerMedium"
	part.Size = Vector3.new(3, 2, 2)
	part.Position = position
	part.Anchored = true
	part.CanCollide = true
	part.Color = Color3.fromRGB(120, 80, 40)
	part.Material = Enum.Material.Wood
	part.Parent = workspace

	-- Tag it as loot container
	CollectionService:AddTag(part, CONTAINER_TAG)
	spawnedContainers[part] = true

	return part
end

local function destroyProgrammaticContainers()
	for part, _ in spawnedContainers do
		if part and part.Parent then
			CollectionService:RemoveTag(part, CONTAINER_TAG)
			part:Destroy()
		end
	end
	spawnedContainers = {}
end

local function spawnProgrammaticContainers()
	for _, pos in CONTAINER_POSITIONS do
		createProgrammaticContainer(pos)
	end
end

local function tagWorkspaceContainers()
	-- Scan Workspace for parts/models with valid container names and tag them
	for _, obj in workspace:GetDescendants() do
		if VALID_CONTAINER_NAMES[obj.Name] then
			if not CollectionService:HasTag(obj, CONTAINER_TAG) then
				CollectionService:AddTag(obj, CONTAINER_TAG)
			end
		end
	end

	-- Watch for new containers added to Workspace
	workspace.DescendantAdded:Connect(function(obj)
		if VALID_CONTAINER_NAMES[obj.Name] then
			if not CollectionService:HasTag(obj, CONTAINER_TAG) then
				CollectionService:AddTag(obj, CONTAINER_TAG)
			end
		end
	end)
end

function ContainerServer.resetContainers()
	-- Destroy and re-create programmatic containers
	destroyProgrammaticContainers()
	spawnProgrammaticContainers()

	-- Re-tag any Workspace containers that may have lost tags
	tagWorkspaceContainers()

	print("[CAG] Containers reset")
end

function ContainerServer.stop()
	-- Demo mode OFF: destroy only programmatic containers
	destroyProgrammaticContainers()
	print("[CAG] ContainerServer stopped")
end

function ContainerServer.start()
	-- Demo mode ON: re-spawn programmatic containers and re-tag
	spawnProgrammaticContainers()
	tagWorkspaceContainers()
	print("[CAG] ContainerServer started")
end

function ContainerServer.init()
	-- Tag existing Workspace containers
	tagWorkspaceContainers()

	-- Spawn programmatic containers at fixed positions
	spawnProgrammaticContainers()

	local totalTagged = #CollectionService:GetTagged(CONTAINER_TAG)
	print("[CAG] ContainerServer initialized (" .. totalTagged .. " containers tagged)")
end

return ContainerServer
