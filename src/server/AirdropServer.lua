--[[
	AirdropServer — one airdrop per match.
	Triggered by RoundServer at 60% match time.
	Sequence: incoming announcement → ETA wait → crate drop → proximity loot → expire.
	Exports: triggerAirdrop, getAirdropState, reset
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local AirdropServer = {}

-- Module references (set during init)
local LootTableServer = nil
local InventoryServer = nil

local airdropState = "idle" -- idle / incoming / landed / looted / expired
local airdropCrate = nil
local airdropPosition = nil
local INTERACT_DISTANCE = 6

local function randomLandingPosition(): Vector3
	local min = Config.Airdrop.MapBoundsMin
	local max = Config.Airdrop.MapBoundsMax
	local x = math.random(math.floor(min.X), math.floor(max.X))
	local z = math.random(math.floor(min.Z), math.floor(max.Z))
	return Vector3.new(x, 1, z)
end

local function createCrate(position: Vector3)
	local crate = Instance.new("Part")
	crate.Name = "AirdropCrate"
	crate.Size = Vector3.new(4, 3, 3)
	crate.Position = position + Vector3.new(0, Config.Airdrop.CrateDropHeight, 0)
	crate.Anchored = true
	crate.CanCollide = true
	crate.Color = Color3.fromRGB(230, 180, 40)
	crate.Material = Enum.Material.Metal

	-- Glow light
	local light = Instance.new("PointLight")
	light.Brightness = 5
	light.Range = 40
	light.Color = Color3.fromRGB(255, 200, 50)
	light.Parent = crate

	-- Billboard label
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "AirdropLabel"
	billboard.Size = UDim2.new(0, 150, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = crate

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "AIRDROP"
	label.TextColor3 = Color3.fromRGB(255, 220, 50)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(100, 80, 0)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = billboard

	crate.Parent = workspace

	-- Drop tween from sky to ground
	TweenService:Create(crate, TweenInfo.new(2, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
		Position = position,
	}):Play()

	return crate
end

function AirdropServer.triggerAirdrop()
	if airdropState ~= "idle" then
		return
	end

	airdropPosition = randomLandingPosition()
	airdropState = "incoming"

	-- Notify all clients
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remotes then
		local incomingRemote = remotes:FindFirstChild(RemoteNames.AirdropIncoming)
		if incomingRemote then
			incomingRemote:FireAllClients({
				position = airdropPosition,
				eta = Config.Airdrop.ETA,
			})
		end
	end

	print("[CAG] Airdrop incoming at " .. tostring(airdropPosition) .. " (ETA " .. Config.Airdrop.ETA .. "s)")

	-- Wait for ETA then land
	task.spawn(function()
		task.wait(Config.Airdrop.ETA)

		if airdropState ~= "incoming" then
			return
		end

		airdropState = "landed"
		airdropCrate = createCrate(airdropPosition)

		-- Notify landed
		if remotes then
			local landedRemote = remotes:FindFirstChild(RemoteNames.AirdropLanded)
			if landedRemote then
				landedRemote:FireAllClients({
					position = airdropPosition,
				})
			end
		end

		print("[CAG] Airdrop landed!")

		-- Proximity interaction loop
		task.spawn(function()
			while airdropState == "landed" do
				for _, player in Players:GetPlayers() do
					local character = player.Character
					if not character then
						continue
					end
					local hrp = character:FindFirstChild("HumanoidRootPart")
					if not hrp then
						continue
					end

					local dist = (hrp.Position - airdropPosition).Magnitude
					if dist <= INTERACT_DISTANCE then
						-- Roll airdrop loot (guaranteed Rare+)
						if LootTableServer and InventoryServer then
							local item = LootTableServer.rollLoot("airdrop", player)
							if item then
								local added = InventoryServer.addItem(player, item)
								if not added then
									local notifRemotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
									if notifRemotes then
										local notifRemote = notifRemotes:FindFirstChild(RemoteNames.ShowNotification)
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

						airdropState = "looted"

						-- Fade and remove crate
						if airdropCrate then
							TweenService:Create(
								airdropCrate,
								TweenInfo.new(0.5),
								{ Transparency = 1 }
							):Play()
							task.wait(0.5)
							if airdropCrate and airdropCrate.Parent then
								airdropCrate:Destroy()
							end
							airdropCrate = nil
						end

						print("[CAG] Airdrop looted by " .. player.Name)
						return
					end
				end

				task.wait(0.2)
			end
		end)

		-- Expire after lifetime
		task.spawn(function()
			task.wait(Config.Airdrop.CrateLifetime)
			if airdropState == "landed" then
				airdropState = "expired"
				if airdropCrate and airdropCrate.Parent then
					TweenService:Create(airdropCrate, TweenInfo.new(1), {
						Transparency = 1,
					}):Play()
					task.wait(1)
					if airdropCrate and airdropCrate.Parent then
						airdropCrate:Destroy()
					end
					airdropCrate = nil
				end
				print("[CAG] Airdrop expired")
			end
		end)
	end)
end

function AirdropServer.getAirdropState(): string
	return airdropState
end

function AirdropServer.reset()
	airdropState = "idle"
	airdropPosition = nil
	if airdropCrate and airdropCrate.Parent then
		airdropCrate:Destroy()
	end
	airdropCrate = nil
end

function AirdropServer.init()
	local serverModules = script.Parent
	local lootModule = serverModules:FindFirstChild("LootTableServer")
	if lootModule then
		LootTableServer = require(lootModule)
	end
	local invModule = serverModules:FindFirstChild("InventoryServer")
	if invModule then
		InventoryServer = require(invModule)
	end

	print("[CAG] AirdropServer initialized")
end

return AirdropServer
