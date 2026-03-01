--[[
	AirdropClient — airdrop incoming/landed notifications and screen indicators.
	Shows ETA countdown, direction arrow, minimap marker pulse.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local AirdropClient = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera
local style = Config.UIStyle

local screenGui = nil
local etaLabel = nil
local directionArrow = nil
local airdropPosition = nil
local airdropLanded = false
local renderConn = nil

local function createAirdropUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AirdropUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = playerGui

	-- ETA countdown (top-center)
	local eta = Instance.new("TextLabel")
	eta.Name = "ETA"
	eta.Size = UDim2.new(0, 250, 0, 40)
	eta.AnchorPoint = Vector2.new(0.5, 0)
	eta.Position = UDim2.new(0.5, 0, 0, 50)
	eta.BackgroundColor3 = style.PanelBG
	eta.BackgroundTransparency = 0.1
	eta.Text = "AIRDROP INCOMING: 15s"
	eta.Font = Enum.Font.FredokaOne
	eta.TextSize = 18
	eta.TextColor3 = Color3.fromRGB(255, 200, 40)
	eta.TextStrokeTransparency = 0
	eta.TextStrokeColor3 = Color3.fromRGB(80, 60, 0)
	eta.Parent = gui

	local etaCorner = Instance.new("UICorner")
	etaCorner.CornerRadius = style.CornerRadius
	etaCorner.Parent = eta

	local etaStroke = Instance.new("UIStroke")
	etaStroke.Color = Color3.fromRGB(255, 180, 40)
	etaStroke.Thickness = 2
	etaStroke.Parent = eta

	-- Direction arrow (screen edge)
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.Size = UDim2.new(0, 60, 0, 60)
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.new(0.5, 0, 0.5, 0)
	arrow.BackgroundTransparency = 1
	arrow.Text = "▼"
	arrow.Font = Enum.Font.GothamBold
	arrow.TextSize = 32
	arrow.TextColor3 = Color3.fromRGB(255, 200, 40)
	arrow.TextStrokeTransparency = 0
	arrow.TextStrokeColor3 = Color3.fromRGB(80, 60, 0)
	arrow.Visible = false
	arrow.Rotation = 0
	arrow.Parent = gui

	-- "AIRDROP" label under arrow
	local arrowLabel = Instance.new("TextLabel")
	arrowLabel.Name = "Label"
	arrowLabel.Size = UDim2.new(0, 80, 0, 18)
	arrowLabel.AnchorPoint = Vector2.new(0.5, 0)
	arrowLabel.Position = UDim2.new(0.5, 0, 1, 2)
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.Text = "AIRDROP"
	arrowLabel.Font = Enum.Font.FredokaOne
	arrowLabel.TextSize = 12
	arrowLabel.TextColor3 = Color3.fromRGB(255, 200, 40)
	arrowLabel.TextStrokeTransparency = 0
	arrowLabel.TextStrokeColor3 = Color3.fromRGB(80, 60, 0)
	arrowLabel.Parent = arrow

	etaLabel = eta
	directionArrow = arrow
	screenGui = gui
	return gui
end

local function updateArrow()
	if not airdropPosition or not directionArrow then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	-- Check if airdrop is on screen
	local viewportSize = camera.ViewportSize
	local screenPos, onScreen = camera:WorldToViewportPoint(airdropPosition)

	if onScreen and screenPos.X > 0 and screenPos.X < viewportSize.X and screenPos.Y > 0 and screenPos.Y < viewportSize.Y then
		directionArrow.Visible = false
		return
	end

	directionArrow.Visible = true

	-- Calculate angle to airdrop
	local toTarget = (airdropPosition - hrp.Position)
	local camCF = camera.CFrame
	local localDir = camCF:VectorToObjectSpace(toTarget)
	local angle = math.atan2(localDir.X, -localDir.Z)

	directionArrow.Rotation = math.deg(angle)

	-- Position on screen edge
	local margin = 60
	local cx, cy = viewportSize.X / 2, viewportSize.Y / 2
	local radius = math.min(cx, cy) - margin

	local ax = cx + math.sin(angle) * radius
	local ay = cy - math.cos(angle) * radius
	ax = math.clamp(ax, margin, viewportSize.X - margin)
	ay = math.clamp(ay, margin, viewportSize.Y - margin)

	directionArrow.Position = UDim2.new(0, ax, 0, ay)
end

function AirdropClient.init()
	createAirdropUI()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	-- Airdrop incoming
	remotes:WaitForChild(RemoteNames.AirdropIncoming).OnClientEvent:Connect(function(data)
		airdropPosition = data.position
		airdropLanded = false

		if screenGui then
			screenGui.Enabled = true
		end

		-- ETA countdown
		local eta = data.eta or Config.Airdrop.ETA
		task.spawn(function()
			for i = eta, 1, -1 do
				if etaLabel then
					etaLabel.Text = "AIRDROP INCOMING: " .. i .. "s"
				end
				task.wait(1)
			end
			if etaLabel then
				etaLabel.Text = "AIRDROP LANDED!"
				task.wait(3)
				etaLabel.Visible = false
			end
		end)

		-- Start arrow updates
		if renderConn then
			renderConn:Disconnect()
		end
		renderConn = RunService.RenderStepped:Connect(function()
			updateArrow()
		end)
	end)

	-- Airdrop landed
	remotes:WaitForChild(RemoteNames.AirdropLanded).OnClientEvent:Connect(function(data)
		airdropLanded = true
		airdropPosition = data.position

		if directionArrow then
			directionArrow.Visible = true
		end
	end)

	-- Cleanup on round end
	remotes:WaitForChild(RemoteNames.RoundStateChanged).OnClientEvent:Connect(function(state)
		if state == "Waiting" or state == "Ended" then
			airdropPosition = nil
			airdropLanded = false

			if renderConn then
				renderConn:Disconnect()
				renderConn = nil
			end

			if screenGui then
				screenGui.Enabled = false
			end

			if etaLabel then
				etaLabel.Visible = true
			end
			if directionArrow then
				directionArrow.Visible = false
			end
		end
	end)
end

return AirdropClient
