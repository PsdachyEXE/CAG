--[[
	ExtractionServer — manages the extraction zone.
	Players stand in the zone for Config.Extraction.Duration seconds to extract.
	Triggers round-end on successful extraction.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local ExtractionServer = {}

local extractionZone = nil
local playersExtracting = {} -- [player] = startTick

local function createExtractionZone()
	local zone = Instance.new("Part")
	zone.Name = "ExtractionZone"
	zone.Size = Config.Extraction.ZoneSize
	zone.Position = Vector3.new(0, Config.Extraction.ZoneSize.Y / 2, 60)
	zone.Anchored = true
	zone.CanCollide = false
	zone.Transparency = Config.Extraction.ZoneTransparency
	zone.Color = Config.Extraction.ZoneColor
	zone.Material = Enum.Material.ForceField

	-- Beam pillar effect
	local beam = Instance.new("PointLight")
	beam.Brightness = 2
	beam.Range = 25
	beam.Color = Config.Extraction.ZoneColor
	beam.Parent = zone

	-- Billboard label
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 8, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = zone

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "EXTRACTION ZONE"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard

	zone.Parent = workspace
	return zone
end

local function isPlayerInZone(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local zonePos = extractionZone.Position
	local zoneSize = extractionZone.Size / 2
	local playerPos = hrp.Position

	return math.abs(playerPos.X - zonePos.X) <= zoneSize.X
		and math.abs(playerPos.Y - zonePos.Y) <= zoneSize.Y + 3 -- extra headroom
		and math.abs(playerPos.Z - zonePos.Z) <= zoneSize.Z
end

local function onRoundEnd(player: Player, extracted: boolean)
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local roundEndRemote = remotes:WaitForChild(RemoteNames.RoundEnd)

	-- Fire to all clients with the extracting player's info
	roundEndRemote:FireAllClients({
		playerName = player.Name,
		extracted = extracted,
		xp = Config.Round.XPPlaceholder,
		loot = { "Placeholder Item A", "Placeholder Item B" },
	})

	print("[CAG] Round ended — " .. player.Name .. (extracted and " extracted!" or " died."))
end

function ExtractionServer.init()
	extractionZone = createExtractionZone()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local progressRemote = remotes:WaitForChild(RemoteNames.ExtractionProgress)
	local completeRemote = remotes:WaitForChild(RemoteNames.ExtractionComplete)
	local cancelRemote = remotes:WaitForChild(RemoteNames.ExtractionCancel)

	-- Monitor players in zone
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local inZone = isPlayerInZone(player)

				if inZone then
					if not playersExtracting[player] then
						-- Start extracting
						playersExtracting[player] = tick()
						remotes:WaitForChild(RemoteNames.ExtractionStart):FireClient(player)
					else
						-- Check progress
						local elapsed = tick() - playersExtracting[player]
						local progress = math.clamp(elapsed / Config.Extraction.Duration, 0, 1)

						progressRemote:FireClient(player, progress)

						if progress >= 1 then
							playersExtracting[player] = nil
							completeRemote:FireClient(player)
							onRoundEnd(player, true)
						end
					end
				else
					if playersExtracting[player] then
						-- Left the zone — cancel
						playersExtracting[player] = nil
						cancelRemote:FireClient(player)
					end
				end
			end

			task.wait(0.1)
		end
	end)

	-- Handle player death during extraction
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")
			humanoid.Died:Connect(function()
				if playersExtracting[player] then
					playersExtracting[player] = nil
				end
				onRoundEnd(player, false)
			end)
		end)
	end)

	-- Cleanup on leave
	Players.PlayerRemoving:Connect(function(player)
		playersExtracting[player] = nil
	end)

	print("[CAG] Extraction system initialized")
end

return ExtractionServer
