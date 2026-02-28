--[[
	WeaponServer — validates raycast hits from clients, applies damage,
	and replicates hit feedback + damage numbers.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local WeaponServer = {}

function WeaponServer.init()
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local weaponHitRemote = remotes:WaitForChild(RemoteNames.WeaponHit)
	local damageNumberRemote = remotes:WaitForChild(RemoteNames.DamageNumber)

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

		humanoid:TakeDamage(damage)

		-- Replicate damage number to all clients
		damageNumberRemote:FireAllClients(hitPosition, damage, isHeadshot)
	end)
end

return WeaponServer
