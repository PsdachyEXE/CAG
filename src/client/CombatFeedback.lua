--[[
	CombatFeedback — hit markers, screen shake scaled to damage, kill flash.
	Listens to server-confirmed hits and player damage events.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local CombatFeedback = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local hitMarkerGui = nil
local killFlashGui = nil
local shakeEndTime = 0
local shakeIntensity = 0
local shakeDuration = 0

local function createHitMarkerUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HitMarkerUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = playerGui

	local size = Config.Weapon.HitMarkerSize

	local container = Instance.new("Frame")
	container.Name = "Marker"
	container.Size = UDim2.new(0, size * 2, 0, size * 2)
	container.Position = UDim2.new(0.5, -size, 0.5, -size)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = gui

	local lineData = {
		{ UDim2.new(0.5, -1, 0, 0),   UDim2.new(0, 3, 0.3, 0), 25 },
		{ UDim2.new(0.5, -1, 0.7, 0), UDim2.new(0, 3, 0.3, 0), 25 },
		{ UDim2.new(0, 0, 0.5, -1),   UDim2.new(0.3, 0, 0, 3), 25 },
		{ UDim2.new(0.7, 0, 0.5, -1), UDim2.new(0.3, 0, 0, 3), 25 },
	}

	for _, data in lineData do
		local line = Instance.new("Frame")
		line.Position = data[1]
		line.Size = data[2]
		line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		line.BorderSizePixel = 0
		line.Rotation = data[3]
		line.Parent = container

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 2)
		corner.Parent = line
	end

	hitMarkerGui = container
	return gui
end

local function createKillFlashUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "KillFlashUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	gui.Parent = playerGui

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui

	killFlashGui = flash
	return gui
end

local function showHitMarker(isHeadshot: boolean)
	if not hitMarkerGui then
		return
	end

	for _, child in hitMarkerGui:GetChildren() do
		if child:IsA("Frame") then
			if isHeadshot then
				child.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
			else
				child.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
	end

	hitMarkerGui.Visible = true

	hitMarkerGui.Size = UDim2.new(0, 60, 0, 60)
	hitMarkerGui.Position = UDim2.new(0.5, -30, 0.5, -30)

	local targetSize = Config.Weapon.HitMarkerSize
	TweenService:Create(hitMarkerGui, TweenInfo.new(0.06, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, targetSize * 2, 0, targetSize * 2),
		Position = UDim2.new(0.5, -targetSize, 0.5, -targetSize),
	}):Play()

	task.spawn(function()
		task.wait(Config.Weapon.HitMarkerDuration)
		hitMarkerGui.Visible = false
	end)
end

local function showKillFlash()
	if not killFlashGui then
		return
	end

	killFlashGui.BackgroundTransparency = 0.6

	TweenService:Create(killFlashGui, TweenInfo.new(Config.Weapon.KillFlashDuration, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 1,
	}):Play()
end

local function triggerScreenShake(damage: number)
	-- Scale intensity with damage amount
	local intensity = damage * Config.Weapon.ScreenShakePerDamage
	intensity = math.clamp(intensity, Config.Weapon.ScreenShakeMin, Config.Weapon.ScreenShakeMax)

	-- If already shaking, use the stronger intensity
	if tick() < shakeEndTime then
		shakeIntensity = math.max(shakeIntensity, intensity)
	else
		shakeIntensity = intensity
	end

	shakeDuration = Config.Weapon.ScreenShakeDuration
	shakeEndTime = tick() + shakeDuration
end

function CombatFeedback.init()
	createHitMarkerUI()
	createKillFlashUI()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	-- Hit confirm from server (hit marker + optional kill flash)
	remotes:WaitForChild(RemoteNames.WeaponHitConfirm).OnClientEvent:Connect(
		function(_hitPosition, isHeadshot, killed)
			showHitMarker(isHeadshot)
			if killed then
				showKillFlash()
			end
		end
	)

	-- Player took damage — screen shake scaled to damage
	remotes:WaitForChild(RemoteNames.PlayerDamaged).OnClientEvent:Connect(function(damage)
		triggerScreenShake(damage)
	end)

	-- Screen shake render loop
	RunService.RenderStepped:Connect(function(_dt)
		camera = workspace.CurrentCamera

		if tick() < shakeEndTime then
			local remaining = shakeEndTime - tick()
			local t = remaining / shakeDuration
			local mag = shakeIntensity * t
			camera.CFrame = camera.CFrame * CFrame.new(
				(math.random() - 0.5) * mag,
				(math.random() - 0.5) * mag,
				0
			)
		end
	end)
end

return CombatFeedback
