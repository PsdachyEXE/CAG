--[[
	ExtractionClient — shows extraction progress bar HUD when inside the extraction zone.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local ExtractionClient = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local extractionGui = nil
local progressBar = nil
local statusLabel = nil

local function createExtractionUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ExtractionUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	-- Container at bottom center
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(0, 300, 0, 50)
	container.Position = UDim2.new(0.5, -150, 0.85, 0)
	container.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	container.BackgroundTransparency = 0.3
	container.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 200, 100)
	stroke.Thickness = 2
	stroke.Parent = container

	-- Label
	local label = Instance.new("TextLabel")
	label.Name = "Status"
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Position = UDim2.new(0, 0, 0, 4)
	label.BackgroundTransparency = 1
	label.Text = "EXTRACTING..."
	label.TextColor3 = Color3.fromRGB(0, 255, 130)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.Parent = container
	statusLabel = label

	-- Progress bar background
	local barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.Size = UDim2.new(0.9, 0, 0, 12)
	barBg.Position = UDim2.new(0.05, 0, 0, 30)
	barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	barBg.Parent = container

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 4)
	barCorner.Parent = barBg

	-- Progress bar fill
	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
	barFill.Parent = barBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = barFill

	progressBar = barFill
	extractionGui = screenGui
end

function ExtractionClient.init()
	createExtractionUI()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	remotes:WaitForChild(RemoteNames.ExtractionStart).OnClientEvent:Connect(function()
		extractionGui.Enabled = true
		statusLabel.Text = "EXTRACTING..."
		progressBar.Size = UDim2.new(0, 0, 1, 0)
	end)

	remotes:WaitForChild(RemoteNames.ExtractionProgress).OnClientEvent:Connect(function(progress)
		progressBar.Size = UDim2.new(progress, 0, 1, 0)
		local pct = math.floor(progress * 100)
		statusLabel.Text = "EXTRACTING... " .. pct .. "%"
	end)

	remotes:WaitForChild(RemoteNames.ExtractionComplete).OnClientEvent:Connect(function()
		statusLabel.Text = "EXTRACTED!"
		statusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
		progressBar.Size = UDim2.new(1, 0, 1, 0)

		task.wait(1)
		extractionGui.Enabled = false
	end)

	remotes:WaitForChild(RemoteNames.ExtractionCancel).OnClientEvent:Connect(function()
		extractionGui.Enabled = false
	end)
end

return ExtractionClient
