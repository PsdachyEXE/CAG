--[[
	WeaponCombatServer — server-authoritative weapon combat.
	Validates WeaponFired from clients, performs raycasts, applies damage.
	Tracks reload state per player. Fires HitConfirmed / PlayerKilled.
	Exports: init
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)
local LootTableData = require(ReplicatedStorage.Shared.LootTableData)

local WeaponCombatServer = {}

-- Module references (resolved in init)
local HotbarServer = nil

-- Build weapon lookup table by id
local weaponLookup = {}
for _, item in LootTableData do
	if item.isWeapon then
		weaponLookup[item.id] = item
	end
end

-- ── Per-player state ──────────────────────────────────────
-- [Player] = { lastFireTime, isReloading, ammo, weaponId }
local playerStates = {}

local function getState(player)
	if not playerStates[player] then
		playerStates[player] = {
			lastFireTime = 0,
			isReloading = false,
			ammo = 0,
			weaponId = nil,
		}
	end
	return playerStates[player]
end

local function getWeaponData(weaponId)
	return weaponLookup[weaponId]
end

-- ── Raycast ───────────────────────────────────────────────
local RAY_MAX_DISTANCE = 1000

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function performRaycast(player, origin, direction)
	-- Exclude the shooter's character
	local character = player.Character
	local filterList = {}
	if character then
		table.insert(filterList, character)
	end
	raycastParams.FilterDescendantsInstances = filterList

	local result = workspace:Raycast(origin, direction * RAY_MAX_DISTANCE, raycastParams)
	return result
end

local function findHumanoidFromPart(part)
	-- Walk up parents to find a character with a Humanoid
	local current = part
	while current and current ~= workspace do
		local humanoid = current:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid, current
		end
		current = current.Parent
	end
	return nil, nil
end

local function isHeadshotPart(part)
	return part.Name == "Head"
end

-- ── Validation helpers ────────────────────────────────────
local ORIGIN_TOLERANCE = 15 -- studs from HRP; generous for network lag
local FIRE_RATE_TOLERANCE = 0.85 -- allow 85% of theoretical minimum interval

local function validateOrigin(player, origin)
	local character = player.Character
	if not character then
		return false
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	return (origin - hrp.Position).Magnitude <= ORIGIN_TOLERANCE
end

local function validateDirection(direction)
	if typeof(direction) ~= "Vector3" then
		return false
	end
	local mag = direction.Magnitude
	return mag > 0.5 and mag < 1.5
end

local function getEquippedWeaponData(player)
	if not HotbarServer then
		return nil
	end
	local hb = HotbarServer.getHotbar(player)
	if not hb or not hb.equippedSlot then
		return nil
	end
	local item = hb.slots[hb.equippedSlot]
	if item and item.isWeapon then
		return item
	end
	return nil
end

-- ── Fire handler ──────────────────────────────────────────
local function handleWeaponFired(player, origin, direction, weaponId, isADS, pelletCount)
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remotes then
		return
	end

	-- Validate types
	if typeof(origin) ~= "Vector3" then
		return
	end
	if not validateDirection(direction) then
		return
	end
	if type(weaponId) ~= "string" then
		return
	end

	-- Validate weapon is equipped
	local equippedItem = getEquippedWeaponData(player)
	if not equippedItem or equippedItem.id ~= weaponId then
		return
	end

	local weaponData = getWeaponData(weaponId)
	if not weaponData then
		return
	end

	-- Validate origin proximity
	if not validateOrigin(player, origin) then
		return
	end

	-- State checks
	local state = getState(player)

	-- Reload check
	if state.isReloading then
		return
	end

	-- Fire rate enforcement
	local now = tick()
	local fireInterval = 60 / (weaponData.fireRate or 600)
	if now - state.lastFireTime < fireInterval * FIRE_RATE_TOLERANCE then
		return
	end
	state.lastFireTime = now

	-- ── Perform raycast(s) ────────────────────────────────
	local hitRemote = remotes:FindFirstChild(RemoteNames.HitConfirmed)
	local killRemote = remotes:FindFirstChild(RemoteNames.PlayerKilled)

	local actualPellets = 1
	if pelletCount and type(pelletCount) == "number" and weaponData.pellets then
		actualPellets = math.min(math.floor(pelletCount), weaponData.pellets)
		if actualPellets < 1 then
			actualPellets = 1
		end
	end

	local baseDamage = weaponData.damage or 10
	local headMultiplier = 2

	for _ = 1, actualPellets do
		-- For shotgun pellets the client sends a single direction
		-- but server re-spreads to prevent client manipulation
		local fireDir = direction
		if actualPellets > 1 then
			-- Server-side spread for pellets
			local spreadAngle = math.rad(weaponData.pelletSpread or 10)
			local angle = spreadAngle * math.random()
			local theta = math.random() * math.pi * 2

			local right = fireDir:Cross(Vector3.new(0, 1, 0))
			if right.Magnitude < 0.01 then
				right = fireDir:Cross(Vector3.new(1, 0, 0))
			end
			right = right.Unit

			local up = right:Cross(fireDir).Unit
			local offset = (right * math.cos(theta) + up * math.sin(theta)) * math.sin(angle)
			fireDir = (fireDir.Unit + offset).Unit
		end

		local result = performRaycast(player, origin, fireDir)
		if result and result.Instance then
			local humanoid, characterModel = findHumanoidFromPart(result.Instance)
			if humanoid and humanoid.Health > 0 then
				-- Determine if headshot
				local headshot = isHeadshotPart(result.Instance)
				local damage = headshot and (baseDamage * headMultiplier) or baseDamage

				-- Apply damage
				humanoid:TakeDamage(damage)

				-- Confirm hit to shooter
				if hitRemote then
					hitRemote:FireClient(player, headshot, damage, result.Position)
				end

				-- Check for kill
				if humanoid.Health <= 0 then
					-- Find victim player
					local victimPlayer = Players:GetPlayerFromCharacter(characterModel)
					local victimName = "Unknown"
					if victimPlayer then
						victimName = victimPlayer.DisplayName or victimPlayer.Name
					elseif characterModel then
						victimName = characterModel.Name
					end

					local killerName = player.DisplayName or player.Name
					local weaponName = weaponData.name or "Unknown Weapon"

					-- Broadcast kill to all clients
					if killRemote then
						for _, plr in Players:GetPlayers() do
							killRemote:FireClient(plr, killerName, victimName, weaponName)
						end
					end
				end
			end
		end
	end
end

-- ── Reload handler ────────────────────────────────────────
local function handleReloadStarted(player)
	local equippedItem = getEquippedWeaponData(player)
	if not equippedItem then
		return
	end

	local state = getState(player)
	if state.isReloading then
		return
	end

	state.isReloading = true

	local weaponData = getWeaponData(equippedItem.id)
	local reloadTime = (weaponData and weaponData.reloadTime) or 2.0

	task.spawn(function()
		task.wait(reloadTime)

		-- Verify player still exists and still has weapon equipped
		if not player.Parent then
			return
		end

		local currentEquipped = getEquippedWeaponData(player)
		if currentEquipped and currentEquipped.id == equippedItem.id then
			state.isReloading = false

			-- Fire completion to client
			local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
			if remotes then
				local reloadRemote = remotes:FindFirstChild(RemoteNames.ReloadComplete)
				if reloadRemote then
					reloadRemote:FireClient(player)
				end
			end
		else
			-- Weapon changed during reload, just clear state
			state.isReloading = false
		end
	end)
end

-- ── Init ──────────────────────────────────────────────────
function WeaponCombatServer.init()
	-- Resolve module references
	local serverModules = script.Parent
	local hotbarMod = serverModules:FindFirstChild("HotbarServer")
	if hotbarMod then
		HotbarServer = require(hotbarMod)
	end

	-- Clean up on player leave
	Players.PlayerRemoving:Connect(function(player)
		playerStates[player] = nil
	end)

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	-- Listen for combat remotes
	remotes:WaitForChild(RemoteNames.WeaponFired).OnServerEvent:Connect(function(player, origin, direction, weaponId, isADS, pelletCount)
		task.spawn(function()
			handleWeaponFired(player, origin, direction, weaponId, isADS, pelletCount)
		end)
	end)

	remotes:WaitForChild(RemoteNames.ReloadStarted).OnServerEvent:Connect(function(player)
		task.spawn(function()
			handleReloadStarted(player)
		end)
	end)

	print("[CAG] WeaponCombatServer initialized")
end

return WeaponCombatServer
