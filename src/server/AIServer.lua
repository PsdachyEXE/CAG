--[[
	AIServer — spawns AI enemies in waves, handles pathfinding with stuck detection,
	separation steering, flanking after LOS timeout, stagger on hit, death scatter,
	and wave-based scaling (size + speed).
	Exports: getCurrentWave, startWaves, stopWaves, reset
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local AIServer = {}

local activeAIs = {}
local remotes
local currentWave = 0
local waveLoopActive = false
local RoundServerRef = nil

function AIServer.getCurrentWave(): number
	return currentWave
end

local function createAIModel(waveNumber: number)
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
		{ "Left Arm", CFrame.new(-1.5, 0, 0) },
		{ "Right Arm", CFrame.new(1.5, 0, 0) },
		{ "Left Leg", CFrame.new(-0.5, -2, 0) },
		{ "Right Leg", CFrame.new(0.5, -2, 0) },
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

	-- Scale speed with wave number
	local speedBonus = (waveNumber - 1) * Config.AI.SpeedScalePerWave
	local moveSpeed = Config.AI.MoveSpeed + speedBonus

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = Config.AI.Health
	humanoid.Health = Config.AI.Health
	humanoid.WalkSpeed = moveSpeed
	humanoid.Parent = model

	model.PrimaryPart = torso
	return model, moveSpeed
end

local function getClosestPlayer(aiPosition: Vector3): Player?
	local closest = nil
	local closestDist = Config.AI.DetectionRange

	for _, plr in Players:GetPlayers() do
		local character = plr.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			local hum = character:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local dist = (hrp.Position - aiPosition).Magnitude
				if dist < closestDist then
					closest = plr
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

	local sign = math.random() > 0.5 and 1 or -1
	local angle = math.rad(Config.AI.FlankAngle * sign)
	local rotatedDir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(flatDir)

	return targetPos - rotatedDir * Config.AI.FlankDistance
end

-- Separation steering: push AI away from nearby AI
local function getSeparationForce(aiData): Vector3
	local rootPart = aiData.model.PrimaryPart
	if not rootPart then
		return Vector3.zero
	end

	local myPos = rootPart.Position
	local force = Vector3.zero

	for _, other in activeAIs do
		if other ~= aiData and other.alive then
			local otherRoot = other.model.PrimaryPart
			if otherRoot then
				local diff = myPos - otherRoot.Position
				local dist = diff.Magnitude
				if dist < Config.AI.SeparationDistance and dist > 0.1 then
					force = force + diff.Unit * (Config.AI.SeparationForce / dist)
				end
			end
		end
	end

	return force
end

local function runAI(aiData)
	local model = aiData.model
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local rootPart = model.PrimaryPart

	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end

	-- Stagger check
	if aiData.staggerUntil and tick() < aiData.staggerUntil then
		return
	end

	-- Stuck detection: compare position to 2 seconds ago
	local now = tick()
	if aiData.lastStuckCheck then
		if now - aiData.lastStuckCheck >= Config.AI.StuckTimeout then
			local dist = (rootPart.Position - aiData.lastStuckPos).Magnitude
			if dist < Config.AI.StuckThreshold then
				humanoid.Jump = true
				aiData.lastPathfind = 0
			end
			aiData.lastStuckCheck = now
			aiData.lastStuckPos = rootPart.Position
		end
	else
		aiData.lastStuckCheck = now
		aiData.lastStuckPos = rootPart.Position
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
		if now - aiData.lastAttack >= Config.AI.AttackCooldown then
			aiData.lastAttack = now
			local targetHumanoid = target.Character:FindFirstChildOfClass("Humanoid")
			if targetHumanoid and targetHumanoid.Health > 0 then
				targetHumanoid:TakeDamage(Config.AI.AttackDamage)

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

	-- Pathfind interval check
	if now - aiData.lastPathfind < Config.AI.PathfindingInterval then
		return
	end
	aiData.lastPathfind = now

	-- Determine destination: direct, flank, or separation-adjusted
	local destination = targetHRP.Position
	local canSee = hasLineOfSight(rootPart.Position, targetHRP.Position, model)

	if canSee then
		aiData.losLostTime = nil
	else
		if not aiData.losLostTime then
			aiData.losLostTime = now
		end
		if now - aiData.losLostTime >= Config.AI.FlankLOSTimeout then
			destination = getFlankPosition(rootPart.Position, targetHRP.Position)
		end
	end

	-- Apply separation steering
	local sepForce = getSeparationForce(aiData)
	if sepForce.Magnitude > 0.1 then
		destination = destination + Vector3.new(sepForce.X, 0, sepForce.Z)
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

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			for _, child in part:GetChildren() do
				if child:IsA("Weld") or child:IsA("WeldConstraint") then
					child:Destroy()
				end
			end
		end
	end

	for _, child in rootPart:GetChildren() do
		if child:IsA("Weld") or child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end

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
			part:ApplyAngularImpulse(Vector3.new(
				(math.random() - 0.5) * 30,
				(math.random() - 0.5) * 30,
				(math.random() - 0.5) * 30
			))
		end
	end

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

	local baseSpeed = aiData.moveSpeed or Config.AI.MoveSpeed
	humanoid.WalkSpeed = baseSpeed * Config.AI.StaggerSpeedMult

	task.spawn(function()
		task.wait(Config.AI.StaggerDuration)
		if humanoid and humanoid.Parent and humanoid.Health > 0 then
			humanoid.WalkSpeed = baseSpeed
		end
	end)
end

local function spawnAI(position: Vector3, waveNumber: number)
	local model, moveSpeed = createAIModel(waveNumber)
	model:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	model.Parent = workspace

	local humanoid = model:FindFirstChildOfClass("Humanoid")

	local aiData = {
		model = model,
		moveSpeed = moveSpeed,
		lastAttack = 0,
		lastPathfind = 0,
		staggerUntil = 0,
		alive = true,
		losLostTime = nil,
		lastStuckCheck = nil,
		lastStuckPos = nil,
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

		scatterDeathParts(model)

		-- Notify RoundServer of AI kill (credit closest player)
		if RoundServerRef then
			local rootPart = model.PrimaryPart
			if rootPart then
				local killer = getClosestPlayer(rootPart.Position)
				if killer then
					RoundServerRef.onPlayerKill(killer, "AI")
				end
			end
		end

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
	currentWave += 1
	local waveSize = Config.AI.WaveBaseSize + (currentWave - 1) * Config.AI.WaveGrowth
	local positions = Config.AI.SpawnPositions
	waveSize = math.min(waveSize, #positions)

	local shuffled = table.clone(positions)
	for i = #shuffled, 2, -1 do
		local j = math.random(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end

	for i = 1, waveSize do
		spawnAI(shuffled[i], currentWave)
	end

	print(
		"[CAG] Wave "
			.. currentWave
			.. " spawned: "
			.. waveSize
			.. " enemies (speed +"
			.. ((currentWave - 1) * Config.AI.SpeedScalePerWave)
			.. ")"
	)
end

-- ── Public API ───────────────────────────────────────────

function AIServer.startWaves()
	if waveLoopActive then
		return
	end
	waveLoopActive = true

	-- Spawn initial wave
	spawnWave()

	-- Continuous wave spawner
	task.spawn(function()
		while waveLoopActive do
			task.wait(Config.AI.WaveInterval)
			if waveLoopActive then
				spawnWave()
			end
		end
	end)

	print("[CAG] AI wave spawning started")
end

function AIServer.stopWaves()
	waveLoopActive = false
	print("[CAG] AI wave spawning stopped")
end

function AIServer.reset()
	waveLoopActive = false
	currentWave = 0

	-- Destroy all active AI
	for _, aiData in activeAIs do
		aiData.alive = false
		if aiData.model and aiData.model.Parent then
			aiData.model:Destroy()
		end
	end
	activeAIs = {}

	print("[CAG] AI system reset")
end

function AIServer.stop()
	AIServer.reset()
end

function AIServer.start()
	AIServer.startWaves()
end

function AIServer.init()
	remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	-- Get RoundServer reference for kill notification
	local serverModules = script.Parent
	local roundModule = serverModules:FindFirstChild("RoundServer")
	if roundModule then
		RoundServerRef = require(roundModule)
	end

	-- Do NOT auto-start waves — RoundServer calls startWaves()
	-- If no RoundServer exists, auto-start as fallback
	if not RoundServerRef then
		task.spawn(function()
			if #Players:GetPlayers() == 0 then
				Players.PlayerAdded:Wait()
			end
			task.wait(2)
			AIServer.startWaves()
		end)
	end

	print("[CAG] AI system initialized")
end

return AIServer
