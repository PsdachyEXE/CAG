--[[
	ExtractionServer — manages a circular extraction zone.
	Players stand in the zone for Config.Extraction.Duration seconds to extract.
	Triggers round-end on successful extraction. Includes wave reached in results.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local ExtractionServer = {}

local extractionZone = nil
local playersExtracting = {} -- [player] = startTick

-- Reference to AIServer for wave tracking (set during init)
local AIServer = nil

local function createExtractionZone()
	local radius = Config.Extraction.ZoneRadius

	-- Circular disc on the ground (cylinder part)
	local zone = Instance.new("Part")
	zone.Name = "ExtractionZone"
	zone.Shape = Enum.PartType.Cylinder
	-- Cylinder: X = height (thickness), Y/Z = diameter
	zone.Size = Vector3.new(0.3, radius * 2, radius * 2)
	zone.CFrame = CFrame.new(Config.Extraction.ZonePosition)
		* CFrame.Angles(0, 0, math.rad(90)) -- lay flat
	zone.Anchored = true
	zone.CanCollide = false
	zone.Color = Config.Extraction.ZoneColor
	zone.Material = Enum.Material.Neon
	zone.Transparency = 0.3

	-- Glow light
	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 30
	light.Color = Config.Extraction.ZoneColor
	light.Parent = zone

	-- Billboard label
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 10, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = zone

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "EXTRACT"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 80, 40)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard

	zone.Parent = workspace

	-- Pulsing size tween loop
	local baseSize = zone.Size
	local pulseMin = baseSize * Config.Extraction.PulseMin
	local pulseMax = baseSize * Config.Extraction.PulseMax
	local tweenInfo = TweenInfo.new(
		1 / Config.Extraction.PulseSpeed,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1, -- repeat forever
		true -- reverses
	)

	TweenService:Create(zone, tweenInfo, { Size = pulseMax }):Play()
	-- Start from min for visible pulse
	zone.Size = pulseMin

	return zone
end

local function isPlayerInZone(plr: Player): boolean
	local character = plr.Character
	if not character then
		return false
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid or humanoid.Health <= 0 then
		return false
	end

	-- Circular check on XZ plane
	local zonePos = Config.Extraction.ZonePosition
	local playerPos = hrp.Position
	local dx = playerPos.X - zonePos.X
	local dz = playerPos.Z - zonePos.Z
	local flatDist = math.sqrt(dx * dx + dz * dz)

	return flatDist <= Config.Extraction.ZoneRadius
		and math.abs(playerPos.Y - zonePos.Y) <= 8 -- vertical tolerance
end

local function getWaveReached(): number
	if AIServer and AIServer.getCurrentWave then
		return AIServer.getCurrentWave()
	end
	return 0
end

local function onRoundEnd(plr: Player, extracted: boolean)
	local roundRemotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local roundEndRemote = roundRemotes:WaitForChild(RemoteNames.RoundEnd)

	roundEndRemote:FireAllClients({
		playerName = plr.Name,
		extracted = extracted,
		xp = Config.Round.XPPlaceholder,
		loot = Config.Round.LootPlaceholder,
		streak = Config.Round.StreakPlaceholder,
		waveReached = getWaveReached(),
	})

	print("[CAG] Round ended — " .. plr.Name .. (extracted and " extracted!" or " died.") .. " (wave " .. getWaveReached() .. ")")
end

function ExtractionServer.init()
	-- Get reference to AIServer for wave tracking
	local serverModules = script.Parent
	local aiModule = serverModules:FindFirstChild("AIServer")
	if aiModule then
		AIServer = require(aiModule)
	end

	extractionZone = createExtractionZone()

	local extractRemotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local progressRemote = extractRemotes:WaitForChild(RemoteNames.ExtractionProgress)
	local completeRemote = extractRemotes:WaitForChild(RemoteNames.ExtractionComplete)
	local cancelRemote = extractRemotes:WaitForChild(RemoteNames.ExtractionCancel)

	-- Monitor players in zone
	task.spawn(function()
		while true do
			for _, plr in Players:GetPlayers() do
				local inZone = isPlayerInZone(plr)

				if inZone then
					if not playersExtracting[plr] then
						playersExtracting[plr] = tick()
						extractRemotes:WaitForChild(RemoteNames.ExtractionStart):FireClient(plr)
					else
						local elapsed = tick() - playersExtracting[plr]
						local progress = math.clamp(elapsed / Config.Extraction.Duration, 0, 1)

						progressRemote:FireClient(plr, progress)

						if progress >= 1 then
							playersExtracting[plr] = nil
							completeRemote:FireClient(plr)
							onRoundEnd(plr, true)
						end
					end
				else
					if playersExtracting[plr] then
						playersExtracting[plr] = nil
						cancelRemote:FireClient(plr)
					end
				end
			end

			task.wait(0.1)
		end
	end)

	-- Handle player death during extraction
	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")
			humanoid.Died:Connect(function()
				if playersExtracting[plr] then
					playersExtracting[plr] = nil
				end
				onRoundEnd(plr, false)
			end)
		end)
	end)

	-- Cleanup on leave
	Players.PlayerRemoving:Connect(function(plr)
		playersExtracting[plr] = nil
	end)

	print("[CAG] Extraction system initialized")
end

return ExtractionServer
