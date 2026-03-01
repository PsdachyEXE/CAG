--[[
	ExtractionServer — manages a circular extraction zone.
	Zone starts hidden. RoundServer calls activate() during extraction phase.
	On extraction complete, calls onPlayerExtracted callback if set.
	Exports: activate, deactivate, onPlayerExtracted (callback field)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local ExtractionServer = {}

local extractionZone = nil
local zoneBillboard = nil
local playersExtracting = {} -- [player] = startTick
local active = false

-- Callback set by RoundServer
ExtractionServer.onPlayerExtracted = nil

local function createExtractionZone()
	local radius = Config.Extraction.ZoneRadius

	-- Circular disc on the ground (cylinder part)
	local zone = Instance.new("Part")
	zone.Name = "ExtractionZone"
	zone.Shape = Enum.PartType.Cylinder
	zone.Size = Vector3.new(0.3, radius * 2, radius * 2)
	zone.CFrame = CFrame.new(Config.Extraction.ZonePosition) * CFrame.Angles(0, 0, math.rad(90))
	zone.Anchored = true
	zone.CanCollide = false
	zone.Color = Config.Extraction.ZoneColor
	zone.Material = Enum.Material.Neon
	zone.Transparency = 1 -- start hidden

	-- Glow light
	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 30
	light.Color = Config.Extraction.ZoneColor
	light.Enabled = false
	light.Parent = zone

	-- Billboard label
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 10, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
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
	zoneBillboard = billboard

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

	local zonePos = Config.Extraction.ZonePosition
	local playerPos = hrp.Position
	local dx = playerPos.X - zonePos.X
	local dz = playerPos.Z - zonePos.Z
	local flatDist = math.sqrt(dx * dx + dz * dz)

	return flatDist <= Config.Extraction.ZoneRadius
		and math.abs(playerPos.Y - zonePos.Y) <= 8
end

function ExtractionServer.activate()
	if active then
		return
	end
	active = true

	if extractionZone then
		-- Fade in zone
		TweenService:Create(extractionZone, TweenInfo.new(0.5), { Transparency = 0.3 }):Play()

		-- Enable light
		local light = extractionZone:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = true
		end

		-- Enable billboard
		if zoneBillboard then
			zoneBillboard.Enabled = true
		end

		-- Start pulsing
		local baseSize = Vector3.new(0.3, Config.Extraction.ZoneRadius * 2, Config.Extraction.ZoneRadius * 2)
		local pulseMax = baseSize * Config.Extraction.PulseMax
		local tweenInfo = TweenInfo.new(
			1 / Config.Extraction.PulseSpeed,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1,
			true
		)
		extractionZone.Size = baseSize * Config.Extraction.PulseMin
		TweenService:Create(extractionZone, tweenInfo, { Size = pulseMax }):Play()
	end

	print("[CAG] Extraction zone activated")
end

function ExtractionServer.deactivate()
	if not active then
		return
	end
	active = false

	-- Cancel all extractions
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remotes then
		local cancelRemote = remotes:FindFirstChild(RemoteNames.ExtractionCancel)
		for plr, _ in playersExtracting do
			if cancelRemote then
				cancelRemote:FireClient(plr)
			end
		end
	end
	playersExtracting = {}

	if extractionZone then
		-- Fade out zone
		TweenService:Create(extractionZone, TweenInfo.new(0.5), { Transparency = 1 }):Play()

		local light = extractionZone:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = false
		end

		if zoneBillboard then
			zoneBillboard.Enabled = false
		end
	end

	print("[CAG] Extraction zone deactivated")
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
			if active then
				for _, plr in Players:GetPlayers() do
					local inZone = isPlayerInZone(plr)

					if inZone then
						if not playersExtracting[plr] then
							playersExtracting[plr] = tick()
							remotes:WaitForChild(RemoteNames.ExtractionStart):FireClient(plr)
						else
							local elapsed = tick() - playersExtracting[plr]
							local progress = math.clamp(elapsed / Config.Extraction.Duration, 0, 1)

							progressRemote:FireClient(plr, progress)

							if progress >= 1 then
								playersExtracting[plr] = nil
								completeRemote:FireClient(plr)

								-- Notify RoundServer via callback
								if ExtractionServer.onPlayerExtracted then
									ExtractionServer.onPlayerExtracted(plr)
								end
							end
						end
					else
						if playersExtracting[plr] then
							playersExtracting[plr] = nil
							cancelRemote:FireClient(plr)
						end
					end
				end
			end

			task.wait(0.1)
		end
	end)

	-- Cleanup on leave
	Players.PlayerRemoving:Connect(function(plr)
		playersExtracting[plr] = nil
	end)

	print("[CAG] Extraction system initialized")
end

return ExtractionServer
