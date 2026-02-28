--[[
	AIServer — spawns AI enemies in waves, handles pathfinding with flanking,
	stagger on hit, death scatter effect, and wave-based respawning.
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local AIServer = {}

local activeAIs = {}
local remotes

local function createAIModel()
	local model = Instance.new("Model")
	model.Name = "AIEnemy"

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

	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	local headWeld = Instance.new("Weld")
	headWeld.Part0 = torso
	headWeld.Part1 = head
	headWeld.C0 = CFrame.new(0, 1.75, 0)
	headWeld.Parent = torso

	local limbData = {
		{ "Left Arm",  CFrame.new(-1.5, 0, 0) },
		{ "Right Arm", CFrame.new(1.5, 0, 0)  },
		{ "Left Leg",  CFrame.new(-0.5, -2, 0) },
		{ "Right Leg", CFrame.new(0.5, -2, 0)  },
	}

	for _, info in limbData do
		local limb = Instance.new("Part")
		limb.Name = info[1]
		limb.Size = Vector3.new(1, 2, 1)
		limb.Anchored = false
		limb.CanCollide = false
		limb.BrickColor = BrickColor.new("Bright red")
		limb.Parent = model

		local weld = Instance.new("Weld")
		weld.Part0 = torso
		weld.Part1 = limb
		weld.C0 = info[2]
		weld.Parent = torso
	end

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

local function hasLineOfSight(from: Vector3, to: Vector3, ignoreModel: Model): boolean
	local direction = to - from
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { ignoreModel }

	local result = workspace:Raycast(from, direction, rayParams)
	if not result then
		return true
	end

	-- Check if what we hit is the target character
	local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
	if hitModel and hitModel:FindFirstChildOfClass("Humanoid") then
		return true
	end

	return false
end

local function getFlankPosition(aiPos: Vector3, targetPos: Vector3): Vector3
	local toTarget = (targetPos - aiPos)
	local flatDir = Vector3.new(toTarget.X, 0, toTarget.Z)
	if flatDir.Magnitude < 0.1 then
		return targetPos
	end
	flatDir = flatDir.Unit

	-- Pick a random flank side (left or right)
	local sign = math.random() > 0.5 and 1 or -1
	local angle = math.rad(Config.AI.FlankAngle * sign)
	local rotatedDir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(flatDir)

	return targetPos - rotatedDir * Config.AI.FlankDistance
end

local function runAI(aiData)
	local model = aiData.model
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local rootPart = model.PrimaryPart

	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end

	-- Stagger check — skip movement while staggered
	if aiData.staggerUntil and tick() < aiData.staggerUntil then
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

				-- Notify client for screen shake
				local targetPlayer = Players:GetPlayerFromCharacter(target.Character)
				if targetPlayer then
					remotes:WaitForChild(RemoteNames.PlayerDamaged):FireClient(
						targetPlayer,
						Config.AI.AttackDamage
					)
				end
			end
		end
		return
	end

	-- Pathfind
	if tick() - aiData.lastPathfind < Config.AI.PathfindingInterval then
		return
	end
	aiData.lastPathfind = tick()

	-- Determine destination: direct or flank
	local destination = targetHRP.Position
	local canSee = hasLineOfSight(rootPart.Position, targetHRP.Position, model)

	if not canSee then
		-- Lost LOS — flank around
		destination = getFlankPosition(rootPart.Position, targetHRP.Position)
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	})

	local success = pcall(function()
		path:ComputeAsync(rootPart.Position, destination)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		for i = 2, math.min(#waypoints, 6) do
			if humanoid.Health <= 0 then
				break
			end
			-- Abort if staggered mid-path
			if aiData.staggerUntil and tick() < aiData.staggerUntil then
				break
			end
			humanoid:MoveTo(waypoints[i].Position)
			if waypoints[i].Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			humanoid.MoveToFinished:Wait()
		end
	else
		humanoid:MoveTo(destination)
	end
end

local function scatterDeathParts(model: Model)
	local rootPart = model.PrimaryPart
	if not rootPart then
		return
	end

	local origin = rootPart.Position

	-- Collect all parts, break welds, scatter
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			-- Remove welds
			for _, child in part:GetChildren() do
				if child:IsA("Weld") or child:IsA("WeldConstraint") then
					child:Destroy()
				end
			end
		end
	end

	-- Break all welds on root too
	for _, child in rootPart:GetChildren() do
		if child:IsA("Weld") or child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end

	-- Apply scatter forces
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = true

			local dir = (part.Position - origin)
			if dir.Magnitude < 0.1 then
				dir = Vector3.new(math.random() - 0.5, 1, math.random() - 0.5)
			end
			dir = dir.Unit

			local scatter = dir * Config.AI.DeathScatterForce
				+ Vector3.new(0, Config.AI.DeathScatterForce * 0.8, 0)
				+ Vector3.new(
					(math.random() - 0.5) * Config.AI.DeathScatterForce * 0.5,
					0,
					(math.random() - 0.5) * Config.AI.DeathScatterForce * 0.5
				)

			part:ApplyImpulse(scatter * part.Mass)

			-- Spin
			part:ApplyAngularImpulse(Vector3.new(
				(math.random() - 0.5) * 30,
				(math.random() - 0.5) * 30,
				(math.random() - 0.5) * 30
			))
		end
	end

	-- Clean up after delay
	task.spawn(function()
		task.wait(Config.AI.DeathScatterLifetime)
		if model.Parent then
			model:Destroy()
		end
	end)
end

local function applyStagger(aiData)
	local model = aiData.model
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	aiData.staggerUntil = tick() + Config.AI.StaggerDuration

	-- Slow down during stagger
	local originalSpeed = Config.AI.MoveSpeed
	humanoid.WalkSpeed = originalSpeed * Config.AI.StaggerSpeedMult

	task.spawn(function()
		task.wait(Config.AI.StaggerDuration)
		if humanoid and humanoid.Parent and humanoid.Health > 0 then
			humanoid.WalkSpeed = originalSpeed
		end
	end)
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
		staggerUntil = 0,
		alive = true,
	}

	table.insert(activeAIs, aiData)

	remotes:WaitForChild(RemoteNames.AISpawn):FireAllClients(model)

	-- Stagger on hit
	humanoid.HealthChanged:Connect(function(newHealth)
		if newHealth > 0 and aiData.alive then
			applyStagger(aiData)
		end
	end)

	-- Death handler
	humanoid.Died:Connect(function()
		aiData.alive = false
		remotes:WaitForChild(RemoteNames.AIDied):FireAllClients(model)

		-- Scatter death effect
		scatterDeathParts(model)

		-- Remove from active list
		for i, data in activeAIs do
			if data == aiData then
				table.remove(activeAIs, i)
				break
			end
		end
	end)

	-- AI loop
	task.spawn(function()
		while aiData.alive and model.Parent do
			runAI(aiData)
			task.wait(0.2)
		end
	end)
end

local function spawnWave()
	local positions = Config.AI.SpawnPositions
	local waveSize = math.min(Config.AI.WaveSize, #positions)

	-- Shuffle and pick spawn points
	local shuffled = table.clone(positions)
	for i = #shuffled, 2, -1 do
		local j = math.random(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end

	for i = 1, waveSize do
		spawnAI(shuffled[i])
	end

	print("[CAG] AI wave spawned: " .. waveSize .. " enemies")
end

function AIServer.init()
	remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	-- Wait for at least one player
	if #Players:GetPlayers() == 0 then
		Players.PlayerAdded:Wait()
	end

	task.wait(2)

	-- Spawn initial wave
	spawnWave()

	-- Wave spawner loop
	task.spawn(function()
		while true do
			task.wait(Config.AI.WaveInterval)
			spawnWave()
		end
	end)

	print("[CAG] AI wave system initialized")
end

return AIServer
