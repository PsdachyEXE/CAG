--[[
	SpectatorClient — spectate living players after death.
	Cycle with left/right arrow keys. Shows spectated player name,
	remaining player count, and extraction timer if active.
	Exits on round end.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local SpectatorClient = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local style = Config.UIStyle
local camera = workspace.CurrentCamera

local isSpectating = false
local spectateIndex = 1
local livingPlayers = {}
local screenGui = nil
local renderConn = nil

local function getLivingPlayers(): { Player }
	local alive = {}
	for _, plr in Players:GetPlayers() do
		if plr ~= player and plr.Character then
			local hum = plr.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				table.insert(alive, plr)
			end
		end
	end
	return alive
end

local function createSpectatorUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpectatorUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Enabled = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	-- Eliminated banner
	local banner = Instance.new("TextLabel")
	banner.Name = "EliminatedBanner"
	banner.Size = UDim2.new(0, 400, 0, 60)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0.15, 0)
	banner.BackgroundTransparency = 1
	banner.Text = "ELIMINATED"
	banner.Font = Enum.Font.FredokaOne
	banner.TextSize = 48
	banner.TextColor3 = style.Negative
	banner.TextStrokeTransparency = 0
	banner.TextStrokeColor3 = Color3.fromRGB(80, 15, 15)
	banner.Parent = gui

	-- Spectating info bar (bottom)
	local infoBar = Instance.new("Frame")
	infoBar.Name = "InfoBar"
	infoBar.Size = UDim2.new(0, 350, 0, 50)
	infoBar.AnchorPoint = Vector2.new(0.5, 1)
	infoBar.Position = UDim2.new(0.5, 0, 1, -40)
	infoBar.BackgroundColor3 = style.PanelBG
	infoBar.BackgroundTransparency = 0.1
	infoBar.Parent = gui

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = style.CornerRadius
	barCorner.Parent = infoBar

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = style.PanelBorderBlue
	barStroke.Thickness = 2
	barStroke.Transparency = 0.3
	barStroke.Parent = infoBar

	-- Player name being spectated
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "SpectatingName"
	nameLabel.Size = UDim2.new(0.6, 0, 0.5, 0)
	nameLabel.Position = UDim2.new(0.2, 0, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "Spectating: —"
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 16
	nameLabel.TextColor3 = style.TextPrimary
	nameLabel.Parent = infoBar

	-- Player count
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "PlayerCount"
	countLabel.Size = UDim2.new(0.6, 0, 0.5, 0)
	countLabel.Position = UDim2.new(0.2, 0, 0.5, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = "0 players remaining"
	countLabel.Font = Enum.Font.Gotham
	countLabel.TextSize = 12
	countLabel.TextColor3 = style.TextSecondary
	countLabel.Parent = infoBar

	-- Arrow hints
	local leftArrow = Instance.new("TextLabel")
	leftArrow.Size = UDim2.new(0.1, 0, 1, 0)
	leftArrow.Position = UDim2.new(0, 0, 0, 0)
	leftArrow.BackgroundTransparency = 1
	leftArrow.Text = "◀"
	leftArrow.Font = Enum.Font.GothamBold
	leftArrow.TextSize = 20
	leftArrow.TextColor3 = style.TextSecondary
	leftArrow.Parent = infoBar

	local rightArrow = Instance.new("TextLabel")
	rightArrow.Size = UDim2.new(0.1, 0, 1, 0)
	rightArrow.Position = UDim2.new(0.9, 0, 0, 0)
	rightArrow.BackgroundTransparency = 1
	rightArrow.Text = "▶"
	rightArrow.Font = Enum.Font.GothamBold
	rightArrow.TextSize = 20
	rightArrow.TextColor3 = style.TextSecondary
	rightArrow.Parent = infoBar

	screenGui = gui
	return gui
end

local function startSpectating()
	if isSpectating then
		return
	end
	isSpectating = true

	livingPlayers = getLivingPlayers()
	spectateIndex = 1

	if not screenGui then
		return
	end
	screenGui.Enabled = true

	-- Fade out banner after 3s
	local banner = screenGui:FindFirstChild("EliminatedBanner")
	if banner then
		banner.TextTransparency = 0
		banner.TextStrokeTransparency = 0
		task.spawn(function()
			task.wait(3)
			TweenService:Create(banner, TweenInfo.new(0.5), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
		end)
	end

	-- Camera follow loop
	renderConn = RunService.RenderStepped:Connect(function(_dt)
		livingPlayers = getLivingPlayers()

		if #livingPlayers == 0 then
			return
		end

		spectateIndex = math.clamp(spectateIndex, 1, #livingPlayers)
		local target = livingPlayers[spectateIndex]

		if target and target.Character then
			local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
			if targetHRP then
				camera.CameraType = Enum.CameraType.Scriptable
				local targetCF = targetHRP.CFrame
				camera.CFrame = targetCF * CFrame.new(0, 5, 12) * CFrame.Angles(math.rad(-15), 0, 0)
			end
		end

		-- Update UI
		local infoBar = screenGui:FindFirstChild("InfoBar")
		if infoBar then
			local nameLabel = infoBar:FindFirstChild("SpectatingName")
			if nameLabel and target then
				nameLabel.Text = "Spectating: " .. target.Name
			end

			local countLabel = infoBar:FindFirstChild("PlayerCount")
			if countLabel then
				countLabel.Text = #livingPlayers .. " player" .. (#livingPlayers ~= 1 and "s" or "") .. " remaining"
			end
		end
	end)
end

local function stopSpectating()
	if not isSpectating then
		return
	end
	isSpectating = false

	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end

	-- Restore camera
	camera.CameraType = Enum.CameraType.Custom

	if screenGui then
		screenGui.Enabled = false
	end
end

function SpectatorClient.init()
	createSpectatorUI()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	-- Input handling for cycling
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not isSpectating then
			return
		end

		if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.A then
			spectateIndex = spectateIndex - 1
			if spectateIndex < 1 then
				spectateIndex = math.max(1, #livingPlayers)
			end
		elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.D then
			spectateIndex = spectateIndex + 1
			if spectateIndex > #livingPlayers then
				spectateIndex = 1
			end
		end
	end)

	-- Start spectating on death
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			task.wait(1) -- brief delay
			startSpectating()
		end)
	end)

	-- Stop spectating on round end
	remotes:WaitForChild(RemoteNames.RoundEnd).OnClientEvent:Connect(function(_data)
		stopSpectating()
	end)

	-- Stop on new round start
	remotes:WaitForChild(RemoteNames.RoundStateChanged).OnClientEvent:Connect(function(state)
		if state == "Active" or state == "Waiting" then
			stopSpectating()
		end
	end)
end

return SpectatorClient
