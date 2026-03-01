--[[
	MainMenuClient — shown during Waiting round state.
	Displays player name, level, XP bar, currency, equipped weapon.
	PLAY button fires PlayerReady to server.
	Clean, consistent with in-game cartoon style.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local MainMenuClient = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local style = Config.UIStyle

local screenGui = nil
local isVisible = true

local function createMainMenuUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MainMenuUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	-- Background
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
	bg.BackgroundTransparency = 0.3
	bg.Parent = gui

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, 400, 0, 80)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0.08, 0)
	title.BackgroundTransparency = 1
	title.Text = "C . A . G"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 72
	title.TextColor3 = Color3.fromRGB(233, 69, 96)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.fromRGB(80, 20, 30)
	title.Parent = bg

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(0, 400, 0, 30)
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.new(0.5, 0, 0.08, 80)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "CARTOONY EXTRACTION SHOOTER"
	subtitle.Font = Enum.Font.GothamBold
	subtitle.TextSize = 14
	subtitle.TextColor3 = style.TextSecondary
	subtitle.Parent = bg

	-- Info card (center)
	local card = Instance.new("Frame")
	card.Name = "InfoCard"
	card.Size = UDim2.new(0, 360, 0, 260)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.48, 0)
	card.BackgroundColor3 = style.PanelBG
	card.BackgroundTransparency = 0.05
	card.Parent = bg

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = style.CornerRadius
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = style.PanelBorderRed
	cardStroke.Thickness = 2
	cardStroke.Parent = card

	-- Player name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.Size = UDim2.new(1, -24, 0, 32)
	nameLabel.Position = UDim2.new(0, 12, 0, 16)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.Name
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextSize = 24
	nameLabel.TextColor3 = style.TextPrimary
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = card

	-- Level
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "Level"
	levelLabel.Size = UDim2.new(1, -24, 0, 24)
	levelLabel.Position = UDim2.new(0, 12, 0, 52)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Level 1"
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.TextSize = 18
	levelLabel.TextColor3 = Color3.fromRGB(255, 200, 40)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Parent = card

	-- XP Bar background
	local xpBarBG = Instance.new("Frame")
	xpBarBG.Name = "XPBarBG"
	xpBarBG.Size = UDim2.new(1, -24, 0, 14)
	xpBarBG.Position = UDim2.new(0, 12, 0, 82)
	xpBarBG.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	xpBarBG.BorderSizePixel = 0
	xpBarBG.Parent = card

	local xpBarCorner = Instance.new("UICorner")
	xpBarCorner.CornerRadius = UDim.new(0, 7)
	xpBarCorner.Parent = xpBarBG

	-- XP Bar fill
	local xpBarFill = Instance.new("Frame")
	xpBarFill.Name = "Fill"
	xpBarFill.Size = UDim2.new(0, 0, 1, 0)
	xpBarFill.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
	xpBarFill.BorderSizePixel = 0
	xpBarFill.Parent = xpBarBG

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 7)
	fillCorner.Parent = xpBarFill

	-- XP text
	local xpText = Instance.new("TextLabel")
	xpText.Name = "XPText"
	xpText.Size = UDim2.new(1, -24, 0, 18)
	xpText.Position = UDim2.new(0, 12, 0, 100)
	xpText.BackgroundTransparency = 1
	xpText.Text = "0 / 100 XP"
	xpText.Font = Enum.Font.Gotham
	xpText.TextSize = 12
	xpText.TextColor3 = style.TextSecondary
	xpText.TextXAlignment = Enum.TextXAlignment.Left
	xpText.Parent = card

	-- Currency
	local currencyLabel = Instance.new("TextLabel")
	currencyLabel.Name = "Currency"
	currencyLabel.Size = UDim2.new(1, -24, 0, 24)
	currencyLabel.Position = UDim2.new(0, 12, 0, 130)
	currencyLabel.BackgroundTransparency = 1
	currencyLabel.Text = "0 Credits"
	currencyLabel.Font = Enum.Font.FredokaOne
	currencyLabel.TextSize = 20
	currencyLabel.TextColor3 = style.Positive
	currencyLabel.TextXAlignment = Enum.TextXAlignment.Left
	currencyLabel.Parent = card

	-- Stats
	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "Stats"
	statsLabel.Size = UDim2.new(1, -24, 0, 40)
	statsLabel.Position = UDim2.new(0, 12, 0, 164)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text = "Matches: 0 | Extractions: 0"
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextSize = 13
	statsLabel.TextColor3 = style.TextSecondary
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextWrapped = true
	statsLabel.Parent = card

	-- Equipped weapon
	local weaponLabel = Instance.new("TextLabel")
	weaponLabel.Name = "Weapon"
	weaponLabel.Size = UDim2.new(1, -24, 0, 24)
	weaponLabel.Position = UDim2.new(0, 12, 0, 210)
	weaponLabel.BackgroundTransparency = 1
	weaponLabel.Text = "Weapon: Default"
	weaponLabel.Font = Enum.Font.GothamBold
	weaponLabel.TextSize = 14
	weaponLabel.TextColor3 = style.TextPrimary
	weaponLabel.TextXAlignment = Enum.TextXAlignment.Left
	weaponLabel.Parent = card

	-- PLAY button
	local playBtn = Instance.new("TextButton")
	playBtn.Name = "PlayButton"
	playBtn.Size = UDim2.new(0, 240, 0, 60)
	playBtn.AnchorPoint = Vector2.new(0.5, 0)
	playBtn.Position = UDim2.new(0.5, 0, 0.78, 0)
	playBtn.BackgroundColor3 = Color3.fromRGB(233, 69, 96)
	playBtn.Text = "PLAY"
	playBtn.Font = Enum.Font.FredokaOne
	playBtn.TextSize = 32
	playBtn.TextColor3 = Color3.new(1, 1, 1)
	playBtn.AutoButtonColor = true
	playBtn.Parent = bg

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 12)
	btnCorner.Parent = playBtn

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(180, 50, 70)
	btnStroke.Thickness = 3
	btnStroke.Parent = playBtn

	-- Hover effect
	playBtn.MouseEnter:Connect(function()
		TweenService:Create(playBtn, TweenInfo.new(0.1), {
			Size = UDim2.new(0, 250, 0, 64),
		}):Play()
	end)
	playBtn.MouseLeave:Connect(function()
		TweenService:Create(playBtn, TweenInfo.new(0.1), {
			Size = UDim2.new(0, 240, 0, 60),
		}):Play()
	end)

	-- Click handler
	playBtn.MouseButton1Click:Connect(function()
		local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
		local readyRemote = remotes:FindFirstChild(RemoteNames.PlayerReady)
		if readyRemote then
			readyRemote:FireServer()
		end

		-- Press effect
		TweenService:Create(playBtn, TweenInfo.new(0.05), {
			Size = UDim2.new(0, 230, 0, 56),
		}):Play()
		task.wait(0.05)
		TweenService:Create(playBtn, TweenInfo.new(0.1), {
			Size = UDim2.new(0, 240, 0, 60),
		}):Play()
	end)

	-- Settings placeholder
	local settingsBtn = Instance.new("TextButton")
	settingsBtn.Name = "Settings"
	settingsBtn.Size = UDim2.new(0, 120, 0, 36)
	settingsBtn.AnchorPoint = Vector2.new(0.5, 0)
	settingsBtn.Position = UDim2.new(0.5, 0, 0.78, 70)
	settingsBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
	settingsBtn.Text = "SETTINGS"
	settingsBtn.Font = Enum.Font.GothamBold
	settingsBtn.TextSize = 14
	settingsBtn.TextColor3 = style.TextSecondary
	settingsBtn.AutoButtonColor = true
	settingsBtn.Parent = bg

	local setCorner = Instance.new("UICorner")
	setCorner.CornerRadius = UDim.new(0, 8)
	setCorner.Parent = settingsBtn

	screenGui = gui
	return gui
end

function MainMenuClient.init()
	createMainMenuUI()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	-- Show/hide based on round state
	remotes:WaitForChild(RemoteNames.RoundStateChanged).OnClientEvent:Connect(function(state)
		if state == "Active" or state == "Extracting" then
			isVisible = false
			if screenGui then
				TweenService:Create(screenGui:FindFirstChild("Background") or screenGui, TweenInfo.new(0.3), {
					BackgroundTransparency = 1,
				}):Play()
				task.wait(0.3)
				screenGui.Enabled = false
			end
		elseif state == "Waiting" then
			isVisible = true
			if screenGui then
				screenGui.Enabled = true
				local bg = screenGui:FindFirstChild("Background")
				if bg then
					bg.BackgroundTransparency = 0.3
				end
			end
		end
	end)

	-- Update info when XP changes
	remotes:WaitForChild(RemoteNames.XPGained).OnClientEvent:Connect(function(_amount, currentXP, xpNeeded)
		if not screenGui then
			return
		end
		local bg = screenGui:FindFirstChild("Background")
		if not bg then
			return
		end
		local card = bg:FindFirstChild("InfoCard")
		if not card then
			return
		end

		local xpText = card:FindFirstChild("XPText")
		if xpText then
			xpText.Text = currentXP .. " / " .. xpNeeded .. " XP"
		end

		local xpBarBG = card:FindFirstChild("XPBarBG")
		if xpBarBG then
			local fill = xpBarBG:FindFirstChild("Fill")
			if fill then
				local ratio = math.clamp(currentXP / math.max(1, xpNeeded), 0, 1)
				TweenService:Create(fill, TweenInfo.new(0.3), {
					Size = UDim2.new(ratio, 0, 1, 0),
				}):Play()
			end
		end
	end)

	-- Update level on level up
	remotes:WaitForChild(RemoteNames.LevelUp).OnClientEvent:Connect(function(newLevel)
		if not screenGui then
			return
		end
		local bg = screenGui:FindFirstChild("Background")
		if not bg then
			return
		end
		local card = bg:FindFirstChild("InfoCard")
		if not card then
			return
		end

		local levelLabel = card:FindFirstChild("Level")
		if levelLabel then
			levelLabel.Text = "Level " .. newLevel
		end
	end)
end

return MainMenuClient
