--[[
	ContainerServer — manages loot containers placed around the map.
	States: Closed / Open / Looted
	Proximity-based interaction (no click required).
	Containers reset on new round via resetContainers().
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local ContainerServer = {}

-- Module references (set during init)
local LootTableServer = nil
local InventoryServer = nil

local containers = {} -- [containerID] = { part, lid, billboard, state, position }
local INTERACT_DISTANCE = 6
local CONTAINER_STATE = { Closed = "Closed", Open = "Open", Looted = "Looted" }

-- Fixed container positions around the map
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

local function createContainer(id: string, position: Vector3)
	local part = Instance.new("Part")
	part.Name = "Container_" .. id
	part.Size = Vector3.new(3, 2, 2)
	part.Position = position
	part.Anchored = true
	part.CanCollide = true
	part.Color = Color3.fromRGB(120, 80, 40)
	part.Material = Enum.Material.Wood

	-- Lid
	local lid = Instance.new("Part")
	lid.Name = "Lid"
	lid.Size = Vector3.new(3, 0.3, 2)
	lid.CFrame = CFrame.new(position + Vector3.new(0, 1.15, 0))
	lid.Anchored = true
	lid.CanCollide = false
	lid.Color = Color3.fromRGB(100, 65, 30)
	lid.Material = Enum.Material.Wood
	lid.Parent = part

	-- Billboard indicator
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Indicator"
	billboard.Size = UDim2.new(0, 80, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 30
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "LOOT"
	label.TextColor3 = Color3.fromRGB(255, 220, 50)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(80, 60, 0)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = billboard

	part.Parent = workspace

	containers[id] = {
		part = part,
		lid = lid,
		billboard = billboard,
		state = CONTAINER_STATE.Closed,
		position = position,
		closedLidCF = CFrame.new(position + Vector3.new(0, 1.15, 0)),
	}
end

local function openContainer(containerID: string, player: Player)
	local container = containers[containerID]
	if not container or container.state ~= CONTAINER_STATE.Closed then
		return
	end

	container.state = CONTAINER_STATE.Open

	-- Animate lid opening (hinge at back edge)
	local lid = container.lid
	if lid then
		local openCF = container.closedLidCF
			* CFrame.new(0, 0, -1) -- pivot to back edge
			* CFrame.Angles(math.rad(-110), 0, 0)
			* CFrame.new(0, 0, 1)
		TweenService:Create(lid, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = openCF,
		}):Play()
	end

	-- Roll loot
	if LootTableServer then
		local item = LootTableServer.rollLoot("container", player)
		if item and InventoryServer then
			local added = InventoryServer.addItem(player, item)
			if not added then
				-- Inventory full notification
				local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
				if remotes then
					local notifRemote = remotes:FindFirstChild(RemoteNames.ShowNotification)
					if notifRemote then
						notifRemote:FireClient(player, {
							type = "warning",
							text = "Inventory full!",
						})
					end
				end
			end
		end
	end

	container.state = CONTAINER_STATE.Looted

	-- Dim the indicator
	local billboard = container.billboard
	if billboard then
		local label = billboard:FindFirstChildOfClass("TextLabel")
		if label then
			label.Text = "EMPTY"
			label.TextColor3 = Color3.fromRGB(120, 120, 120)
		end
	end
end

function ContainerServer.resetContainers()
	for _, container in containers do
		container.state = CONTAINER_STATE.Closed

		-- Reset lid to closed position
		local lid = container.lid
		if lid and container.closedLidCF then
			lid.CFrame = container.closedLidCF
		end

		-- Reset indicator
		local billboard = container.billboard
		if billboard then
			local label = billboard:FindFirstChildOfClass("TextLabel")
			if label then
				label.Text = "LOOT"
				label.TextColor3 = Color3.fromRGB(255, 220, 50)
			end
		end
	end
	print("[CAG] Containers reset")
end

function ContainerServer.getContainerState(containerID: string): string?
	local container = containers[containerID]
	if not container then
		return nil
	end
	return container.state
end

function ContainerServer.init()
	-- Resolve module references
	local serverModules = script.Parent
	local lootModule = serverModules:FindFirstChild("LootTableServer")
	if lootModule then
		LootTableServer = require(lootModule)
	end
	local invModule = serverModules:FindFirstChild("InventoryServer")
	if invModule then
		InventoryServer = require(invModule)
	end

	-- Create containers at fixed positions
	for i, pos in CONTAINER_POSITIONS do
		createContainer("crate_" .. i, pos)
	end

	-- Proximity-based interaction loop
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local character = player.Character
				if not character then
					continue
				end
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if not hrp then
					continue
				end

				for id, container in containers do
					if container.state ~= CONTAINER_STATE.Closed then
						continue
					end

					local dist = (hrp.Position - container.position).Magnitude
					if dist <= INTERACT_DISTANCE then
						openContainer(id, player)
					end
				end
			end

			task.wait(0.2)
		end
	end)

	print("[CAG] ContainerServer initialized (" .. #CONTAINER_POSITIONS .. " containers)")
end

return ContainerServer
