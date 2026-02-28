--[[
	DamageNumbers — cartoon-style floating damage numbers in world space.
	Numbers pop in with scale, drift sideways randomly, float up, and fade out.
	Headshots are red and bigger.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local DamageNumbers = {}

local activeBillboards = {}

local function createDamageNumber(position: Vector3, damage: number, isHeadshot: boolean)
	-- Random horizontal drift direction
	local driftX = (math.random() - 0.5) * 2 -- -1 to 1

	local anchor = Instance.new("Part")
	anchor.Name = "DmgAnchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = position
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageNumber"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.Adornee = anchor
	billboard.Parent = anchor

	-- Cartoon style: bold, thick stroke, slightly oversized
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(30, 30, 30)

	if isHeadshot then
		label.Text = tostring(math.floor(damage)) .. "!"
		label.TextColor3 = Color3.fromRGB(255, 60, 60)
		billboard.Size = UDim2.new(0, 160, 0, 70)
		-- Start big for pop effect
		billboard.Size = UDim2.new(0, 220, 0, 90)
	else
		label.Text = tostring(math.floor(damage))
		label.TextColor3 = Color3.fromRGB(255, 230, 80)
		billboard.Size = UDim2.new(0, 140, 0, 60)
		-- Start big for pop effect
		billboard.Size = UDim2.new(0, 180, 0, 80)
	end

	label.TextScaled = true
	label.Parent = billboard

	table.insert(activeBillboards, {
		anchor = anchor,
		billboard = billboard,
		label = label,
		startTime = tick(),
		startPosition = position,
		driftX = driftX,
		isHeadshot = isHeadshot,
		popped = false,
	})
end

function DamageNumbers.init()
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local damageNumberRemote = remotes:WaitForChild(RemoteNames.DamageNumber)

	damageNumberRemote.OnClientEvent:Connect(function(position, damage, isHeadshot)
		createDamageNumber(position, damage, isHeadshot)
	end)

	RunService.Heartbeat:Connect(function(_dt)
		local now = tick()
		local toRemove = {}

		for i, data in activeBillboards do
			local elapsed = now - data.startTime
			local lifetime = Config.Weapon.DamageNumberLifetime

			if elapsed >= lifetime then
				table.insert(toRemove, i)
			else
				local alpha = elapsed / lifetime

				-- Pop-in: shrink billboard to target size in first 0.1s
				if not data.popped and elapsed > 0.08 then
					data.popped = true
					if data.isHeadshot then
						data.billboard.Size = UDim2.new(0, 160, 0, 70)
					else
						data.billboard.Size = UDim2.new(0, 140, 0, 60)
					end
				end

				-- Float upward + drift sideways
				local rise = Config.Weapon.DamageNumberRiseSpeed * elapsed
				local drift = data.driftX * Config.Weapon.DamageNumberDrift * elapsed
				data.anchor.Position = data.startPosition + Vector3.new(drift, rise, 0)

				-- Fade out in second half
				local fadeAlpha = math.clamp((alpha - 0.4) / 0.6, 0, 1)
				data.label.TextTransparency = fadeAlpha
				data.label.TextStrokeTransparency = fadeAlpha

				-- Slight scale-down as it fades
				local shrink = 1 - (fadeAlpha * 0.3)
				local baseW = data.isHeadshot and 160 or 140
				local baseH = data.isHeadshot and 70 or 60
				data.billboard.Size = UDim2.new(
					0, math.floor(baseW * shrink),
					0, math.floor(baseH * shrink)
				)
			end
		end

		for i = #toRemove, 1, -1 do
			local idx = toRemove[i]
			local data = activeBillboards[idx]
			data.anchor:Destroy()
			table.remove(activeBillboards, idx)
		end
	end)
end

return DamageNumbers
