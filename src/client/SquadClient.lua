--[[
	SquadClient — squad UI panel, invite notifications, squad member markers.
	Top-left compact panel showing squad member names + health bars.
	Toast popup for invites with accept/decline.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local SquadClient = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local style = Config.UIStyle

local screenGui = nil
local squadPanel = nil
local memberFrames = {} -- [playerName] = frame
local invitePopup = nil

-- ── UI Creation ──────────────────────────────────────────

local function createSquadPanel()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SquadUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Parent = playerGui

	-- Squad panel (top-left)
	local panel = Instance.new("Frame")
	panel.Name = "SquadPanel"
	panel.Size = UDim2.new(0, 200, 0, 30)
	panel.Position = UDim2.new(0, 12, 0, 80)
	panel.BackgroundColor3 = style.PanelBG
	panel.BackgroundTransparency = style.PanelBGTransparency
	panel.Visible = false
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = style.CornerRadius
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = style.PanelBorderBlue
	stroke.Thickness = style.DropShadowThickness
	stroke.Transparency = style.DropShadowTransparency
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 24)
	title.Position = UDim2.new(0, 0, 0, 4)
	title.BackgroundTransparency = 1
	title.Text = "SQUAD"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 16
	title.TextColor3 = style.TextPrimary
	title.Parent = panel

	-- Members container (below title)
	local membersContainer = Instance.new("Frame")
	membersContainer.Name = "Members"
	membersContainer.Size = UDim2.new(1, -16, 1, -32)
	membersContainer.Position = UDim2.new(0, 8, 0, 28)
	membersContainer.BackgroundTransparency = 1
	membersContainer.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 4)
	layout.Parent = membersContainer

	squadPanel = panel
	screenGui = gui
	return gui
end

local function createMemberFrame(memberName: string, parent: Instance)
	local frame = Instance.new("Frame")
	frame.Name = memberName
	frame.Size = UDim2.new(1, 0, 0, 22)
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(0.5, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = memberName
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = style.TextPrimary
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = frame

	-- Health bar background
	local barBG = Instance.new("Frame")
	barBG.Name = "BarBG"
	barBG.Size = UDim2.new(0.45, 0, 0, 8)
	barBG.Position = UDim2.new(0.52, 0, 0.5, -4)
	barBG.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	barBG.BorderSizePixel = 0
	barBG.Parent = frame

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 4)
	barCorner.Parent = barBG

	-- Health bar fill
	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.new(1, 0, 1, 0)
	barFill.BackgroundColor3 = style.Positive
	barFill.BorderSizePixel = 0
	barFill.Parent = barBG

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = barFill

	-- Status icon (dot)
	local dot = Instance.new("Frame")
	dot.Name = "StatusDot"
	dot.Size = UDim2.new(0, 6, 0, 6)
	dot.Position = UDim2.new(1, -8, 0.5, -3)
	dot.BackgroundColor3 = style.Positive
	dot.Parent = frame

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	return frame
end

local function createInvitePopup()
	local popup = Instance.new("Frame")
	popup.Name = "InvitePopup"
	popup.Size = UDim2.new(0, 280, 0, 90)
	popup.AnchorPoint = Vector2.new(0.5, 0)
	popup.Position = UDim2.new(0.5, 0, 0, -100) -- off-screen
	popup.BackgroundColor3 = style.PanelBG
	popup.BackgroundTransparency = 0.05
	popup.Parent = screenGui

	local popCorner = Instance.new("UICorner")
	popCorner.CornerRadius = style.CornerRadius
	popCorner.Parent = popup

	local popStroke = Instance.new("UIStroke")
	popStroke.Color = Color3.fromRGB(33, 150, 243)
	popStroke.Thickness = 2
	popStroke.Parent = popup

	local invText = Instance.new("TextLabel")
	invText.Name = "InviteText"
	invText.Size = UDim2.new(1, -16, 0, 40)
	invText.Position = UDim2.new(0, 8, 0, 8)
	invText.BackgroundTransparency = 1
	invText.Text = ""
	invText.Font = Enum.Font.GothamBold
	invText.TextSize = 14
	invText.TextColor3 = style.TextPrimary
	invText.TextWrapped = true
	invText.Parent = popup

	-- Accept button
	local acceptBtn = Instance.new("TextButton")
	acceptBtn.Name = "Accept"
	acceptBtn.Size = UDim2.new(0, 100, 0, 30)
	acceptBtn.Position = UDim2.new(0, 20, 1, -38)
	acceptBtn.BackgroundColor3 = style.Positive
	acceptBtn.Text = "ACCEPT"
	acceptBtn.Font = Enum.Font.FredokaOne
	acceptBtn.TextSize = 14
	acceptBtn.TextColor3 = Color3.new(1, 1, 1)
	acceptBtn.Parent = popup

	local accCorner = Instance.new("UICorner")
	accCorner.CornerRadius = UDim.new(0, 6)
	accCorner.Parent = acceptBtn

	-- Decline button
	local declineBtn = Instance.new("TextButton")
	declineBtn.Name = "Decline"
	declineBtn.Size = UDim2.new(0, 100, 0, 30)
	declineBtn.Position = UDim2.new(1, -120, 1, -38)
	declineBtn.BackgroundColor3 = style.Negative
	declineBtn.Text = "DECLINE"
	declineBtn.Font = Enum.Font.FredokaOne
	declineBtn.TextSize = 14
	declineBtn.TextColor3 = Color3.new(1, 1, 1)
	declineBtn.Parent = popup

	local decCorner = Instance.new("UICorner")
	decCorner.CornerRadius = UDim.new(0, 6)
	decCorner.Parent = declineBtn

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	acceptBtn.MouseButton1Click:Connect(function()
		local acceptRemote = remotes:FindFirstChild(RemoteNames.AcceptSquadInvite)
		if acceptRemote then
			acceptRemote:FireServer()
		end
		TweenService:Create(popup, TweenInfo.new(0.2), {
			Position = UDim2.new(0.5, 0, 0, -100),
		}):Play()
	end)

	declineBtn.MouseButton1Click:Connect(function()
		local declineRemote = remotes:FindFirstChild(RemoteNames.DeclineSquadInvite)
		if declineRemote then
			declineRemote:FireServer()
		end
		TweenService:Create(popup, TweenInfo.new(0.2), {
			Position = UDim2.new(0.5, 0, 0, -100),
		}):Play()
	end)

	invitePopup = popup
	return popup
end

-- ── Update handlers ──────────────────────────────────────

local function updateSquadUI(data)
	if not squadPanel then
		return
	end

	if not data then
		-- No squad
		squadPanel.Visible = false
		memberFrames = {}
		local container = squadPanel:FindFirstChild("Members")
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Frame") then
					child:Destroy()
				end
			end
		end
		return
	end

	squadPanel.Visible = true
	local container = squadPanel:FindFirstChild("Members")
	if not container then
		return
	end

	-- Clear old frames
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	memberFrames = {}

	-- Create new frames
	for _, memberName in data.members do
		local frame = createMemberFrame(memberName, container)
		memberFrames[memberName] = frame
	end

	-- Resize panel to fit members
	local memberCount = #data.members
	squadPanel.Size = UDim2.new(0, 200, 0, 32 + memberCount * 26)
end

local function updateSquadHealth(healthData)
	if not healthData then
		return
	end

	for _, entry in healthData do
		local frame = memberFrames[entry.name]
		if frame then
			local barBG = frame:FindFirstChild("BarBG")
			if barBG then
				local fill = barBG:FindFirstChild("Fill")
				if fill then
					local ratio = math.clamp(entry.health / entry.maxHealth, 0, 1)
					TweenService:Create(fill, TweenInfo.new(0.2), {
						Size = UDim2.new(ratio, 0, 1, 0),
					}):Play()

					-- Color based on health
					if ratio > 0.6 then
						fill.BackgroundColor3 = style.Positive
					elseif ratio > 0.3 then
						fill.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
					else
						fill.BackgroundColor3 = style.Negative
					end
				end
			end
		end
	end
end

local function showInvite(data)
	if not invitePopup then
		return
	end

	local text = invitePopup:FindFirstChild("InviteText")
	if text then
		text.Text = data.from .. " invited you to their squad!"
	end

	TweenService:Create(invitePopup, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 20),
	}):Play()

	-- Auto-dismiss after 30s
	task.spawn(function()
		task.wait(30)
		if invitePopup.Position.Y.Offset > -50 then
			TweenService:Create(invitePopup, TweenInfo.new(0.2), {
				Position = UDim2.new(0.5, 0, 0, -100),
			}):Play()
		end
	end)
end

function SquadClient.init()
	createSquadPanel()
	createInvitePopup()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	-- Squad update
	remotes:WaitForChild(RemoteNames.SquadUpdate).OnClientEvent:Connect(function(data)
		updateSquadUI(data)
	end)

	-- Health update
	remotes:WaitForChild(RemoteNames.SquadHealthUpdate).OnClientEvent:Connect(function(data)
		updateSquadHealth(data)
	end)

	-- Invite received
	remotes:WaitForChild(RemoteNames.SquadInviteReceived).OnClientEvent:Connect(function(data)
		showInvite(data)
	end)
end

return SquadClient
