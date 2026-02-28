--[[
	DamageNumbers — displays floating damage numbers in world space
	when a hit is confirmed by the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local DamageNumbers = {}

local activeBillboards = {}

local function createDamageNumber(position: Vector3, damage: number, isHeadshot: boolean)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageNumber"
	billboard.Size = UDim2.new(0, 100, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 100

	-- Attach to an invisible anchor part
	local anchor = Instance.new("Part")
	anchor.Name = "DmgAnchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = position
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Parent = workspace

	billboard.Adornee = anchor
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = tostring(math.floor(damage))
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.2

	if isHeadshot then
		label.TextColor3 = Color3.fromRGB(255, 50, 50)
		label.Text = tostring(math.floor(damage)) .. "!"
		billboard.Size = UDim2.new(0, 130, 0, 50)
	else
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	label.Parent = billboard

	table.insert(activeBillboards, {
		anchor = anchor,
		billboard = billboard,
		label = label,
		startTime = tick(),
		startPosition = position,
	})
end

function DamageNumbers.init()
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local damageNumberRemote = remotes:WaitForChild(RemoteNames.DamageNumber)

	damageNumberRemote.OnClientEvent:Connect(function(position, damage, isHeadshot)
		createDamageNumber(position, damage, isHeadshot)
	end)

	-- Animate damage numbers
	RunService.Heartbeat:Connect(function(_dt)
		local now = tick()
		local toRemove = {}

		for i, data in activeBillboards do
			local elapsed = now - data.startTime
			local lifetime = Config.Weapon.DamageNumberLifetime

			if elapsed >= lifetime then
				table.insert(toRemove, i)
			else
				-- Float upward
				local rise = Config.Weapon.DamageNumberRiseSpeed * elapsed
				data.anchor.Position = data.startPosition + Vector3.new(0, rise, 0)

				-- Fade out
				local alpha = elapsed / lifetime
				data.label.TextTransparency = alpha
				data.label.TextStrokeTransparency = 0.2 + (alpha * 0.8)
			end
		end

		-- Clean up expired (iterate backward)
		for i = #toRemove, 1, -1 do
			local idx = toRemove[i]
			local data = activeBillboards[idx]
			data.anchor:Destroy()
			table.remove(activeBillboards, idx)
		end
	end)
end

return DamageNumbers
