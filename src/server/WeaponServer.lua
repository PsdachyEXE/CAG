--[[
	WeaponServer — validates raycast hits from clients, applies damage,
	replicates hit feedback + damage numbers, and notifies kill events.
	Tracks last-hit player on AI for kill credit.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local WeaponServer = {}

-- Track who last hit each AI model for accurate kill credit
local lastHitBy = {} -- [model] = player

function WeaponServer.getLastHitBy(model: Model): Player?
	return lastHitBy[model]
end

function WeaponServer.init()
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local weaponHitRemote = remotes:WaitForChild(RemoteNames.WeaponHit)
	local damageNumberRemote = remotes:WaitForChild(RemoteNames.DamageNumber)
	local hitConfirmRemote = remotes:WaitForChild(RemoteNames.WeaponHitConfirm)
	local aiStaggerRemote = remotes:WaitForChild(RemoteNames.AIStagger)

	weaponHitRemote.OnServerEvent:Connect(function(player, hitPart, hitPosition, isHeadshot)
		if not hitPart or not hitPart:IsA("BasePart") then
			return
		end

		local character = player.Character
		if not character then
			return
		end

		local head = character:FindFirstChild("Head")
		if not head then
			return
		end

		-- Validate distance
		local distance = (head.Position - hitPosition).Magnitude
		if distance > Config.Weapon.MaxRange * 1.1 then
			return
		end

		-- Find the humanoid of the hit target
		local hitModel = hitPart:FindFirstAncestorOfClass("Model")
		if not hitModel then
			return
		end

		local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		-- Don't allow self-damage
		if hitModel == character then
			return
		end

		-- Calculate damage
		local damage = Config.Weapon.Damage
		if isHeadshot then
			damage = damage * Config.Weapon.HeadshotMultiplier
		end

		local wasAlive = humanoid.Health > 0
		humanoid:TakeDamage(damage)
		local killed = wasAlive and humanoid.Health <= 0

		-- Track who last hit this AI
		if hitModel.Name == "AIEnemy" then
			lastHitBy[hitModel] = player
		end

		-- Send hit confirm back to the shooter (for hit marker)
		hitConfirmRemote:FireClient(player, hitPosition, isHeadshot, killed)

		-- Replicate damage number to all clients
		damageNumberRemote:FireAllClients(hitPosition, damage, isHeadshot)

		-- Trigger stagger on AI
		if hitModel.Name == "AIEnemy" then
			aiStaggerRemote:FireAllClients(hitModel)
		end

		-- Clean up last-hit tracking on kill (delayed cleanup)
		if killed and hitModel.Name == "AIEnemy" then
			task.spawn(function()
				task.wait(5)
				lastHitBy[hitModel] = nil
			end)
		end
	end)
end

return WeaponServer
