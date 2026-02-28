--[[
	AIServer — spawns AI enemies, handles pathfinding, attacking, and death.
	AI pathfinds to the nearest player, attacks on contact, and dies with feedback.
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local AIServer = {}

local activeAIs = {}

local AI_TEMPLATE_NAME = "AIEnemy"

local function createAIModel()
	-- Programmatic AI dummy: simple humanoid rig
	local model = Instance.new("Model")
	model.Name = AI_TEMPLATE_NAME

	-- Torso (PrimaryPart)
	local torso = Instance.new("Part")
	torso.Name = "HumanoidRootPart"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Anchored = false
	torso.CanCollide = true
	torso.BrickColor = BrickColor.new("Bright red")
	torso.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.Shape = Enum.PartType.Ball
	head.Anchored = false
	head.CanCollide = false
	head.BrickColor = BrickColor.new("Bright red")
	head.Parent = model

	-- Head face decal
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	-- Weld head to torso
	local headWeld = Instance.new("Weld")
	headWeld.Part0 = torso
	headWeld.Part1 = head
	headWeld.C0 = CFrame.new(0, 1.75, 0)
	headWeld.Parent = torso

	-- Left Arm
	local leftArm = Instance.new("Part")
	leftArm.Name = "Left Arm"
	leftArm.Size = Vector3.new(1, 2, 1)
	leftArm.Anchored = false
	leftArm.CanCollide = false
	leftArm.BrickColor = BrickColor.new("Bright red")
	leftArm.Parent = model

	local leftArmWeld = Instance.new("Weld")
	leftArmWeld.Part0 = torso
	leftArmWeld.Part1 = leftArm
	leftArmWeld.C0 = CFrame.new(-1.5, 0, 0)
	leftArmWeld.Parent = torso

	-- Right Arm
	local rightArm = Instance.new("Part")
	rightArm.Name = "Right Arm"
	rightArm.Size = Vector3.new(1, 2, 1)
	rightArm.Anchored = false
	rightArm.CanCollide = false
	rightArm.BrickColor = BrickColor.new("Bright red")
	rightArm.Parent = model

	local rightArmWeld = Instance.new("Weld")
	rightArmWeld.Part0 = torso
	rightArmWeld.Part1 = rightArm
	rightArmWeld.C0 = CFrame.new(1.5, 0, 0)
	rightArmWeld.Parent = torso

	-- Left Leg
	local leftLeg = Instance.new("Part")
	leftLeg.Name = "Left Leg"
	leftLeg.Size = Vector3.new(1, 2, 1)
	leftLeg.Anchored = false
	leftLeg.CanCollide = false
	leftLeg.BrickColor = BrickColor.new("Bright red")
	leftLeg.Parent = model

	local leftLegWeld = Instance.new("Weld")
	leftLegWeld.Part0 = torso
	leftLegWeld.Part1 = leftLeg
	leftLegWeld.C0 = CFrame.new(-0.5, -2, 0)
	leftLegWeld.Parent = torso

	-- Right Leg
	local rightLeg = Instance.new("Part")
	rightLeg.Name = "Right Leg"
	rightLeg.Size = Vector3.new(1, 2, 1)
	rightLeg.Anchored = false
	rightLeg.CanCollide = false
	rightLeg.BrickColor = BrickColor.new("Bright red")
	rightLeg.Parent = model

	local rightLegWeld = Instance.new("Weld")
	rightLegWeld.Part0 = torso
	rightLegWeld.Part1 = rightLeg
	rightLegWeld.C0 = CFrame.new(0.5, -2, 0)
	rightLegWeld.Parent = torso

	-- Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = Config.AI.Health
	humanoid.Health = Config.AI.Health
	humanoid.WalkSpeed = Config.AI.MoveSpeed
	humanoid.Parent = model

	model.PrimaryPart = torso

	return model
end

local function getClosestPlayer(aiPosition: Vector3): Player?
	local closest = nil
	local closestDist = Config.AI.DetectionRange

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			local hum = character:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local dist = (hrp.Position - aiPosition).Magnitude
				if dist < closestDist then
					closest = player
					closestDist = dist
				end
			end
		end
	end

	return closest
end

local function runAI(aiData)
	local model = aiData.model
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local rootPart = model.PrimaryPart

	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end

	local target = getClosestPlayer(rootPart.Position)
	if not target or not target.Character then
		return
	end

	local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
	if not targetHRP then
		return
	end

	local distance = (targetHRP.Position - rootPart.Position).Magnitude

	-- Attack if in range
	if distance <= Config.AI.AttackRange then
		if tick() - aiData.lastAttack >= Config.AI.AttackCooldown then
			aiData.lastAttack = tick()
			local targetHumanoid = target.Character:FindFirstChildOfClass("Humanoid")
			if targetHumanoid and targetHumanoid.Health > 0 then
				targetHumanoid:TakeDamage(Config.AI.AttackDamage)
			end
		end
		return
	end

	-- Pathfind to player
	if tick() - aiData.lastPathfind < Config.AI.PathfindingInterval then
		return
	end
	aiData.lastPathfind = tick()

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	})

	local success, err = pcall(function()
		path:ComputeAsync(rootPart.Position, targetHRP.Position)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		for i = 2, math.min(#waypoints, 6) do
			if humanoid.Health <= 0 then
				break
			end
			humanoid:MoveTo(waypoints[i].Position)
			if waypoints[i].Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			humanoid.MoveToFinished:Wait()
		end
	else
		-- Fallback: move directly
		humanoid:MoveTo(targetHRP.Position)
	end
end

local function spawnAI(position: Vector3)
	local model = createAIModel()
	model:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	model.Parent = workspace

	local humanoid = model:FindFirstChildOfClass("Humanoid")

	local aiData = {
		model = model,
		lastAttack = 0,
		lastPathfind = 0,
		alive = true,
	}

	table.insert(activeAIs, aiData)

	-- Notify clients
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	remotes:WaitForChild(RemoteNames.AISpawn):FireAllClients(model)

	-- Death handler
	humanoid.Died:Connect(function()
		aiData.alive = false
		remotes:WaitForChild(RemoteNames.AIDied):FireAllClients(model)

		task.wait(2)
		model:Destroy()

		-- Remove from active list
		for i, data in activeAIs do
			if data == aiData then
				table.remove(activeAIs, i)
				break
			end
		end

		-- Respawn after delay
		task.wait(Config.AI.RespawnTime)
		spawnAI(position)
	end)

	-- AI loop
	task.spawn(function()
		while aiData.alive and model.Parent do
			runAI(aiData)
			task.wait(0.2)
		end
	end)
end

function AIServer.init()
	-- Spawn AI at predefined positions (place these in your map)
	-- For now, spawn a few around the origin as demo
	local spawnPositions = {
		Vector3.new(30, 0, 30),
		Vector3.new(-30, 0, 30),
		Vector3.new(30, 0, -30),
		Vector3.new(-30, 0, -30),
	}

	-- Wait for at least one player before spawning AI
	if #Players:GetPlayers() == 0 then
		Players.PlayerAdded:Wait()
	end

	task.wait(2) -- Give the player time to load

	for _, pos in spawnPositions do
		spawnAI(pos)
	end

	print("[CAG] AI system initialized with " .. #spawnPositions .. " spawn points")
end

return AIServer
