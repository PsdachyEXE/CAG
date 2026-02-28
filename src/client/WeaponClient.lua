--[[
	WeaponClient — hitscan raycast weapon with ammo tracking.
	Click to fire, R to reload. Hold-to-fire supported.
	Sends hit info to server. Local hit highlighting.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local WeaponClient = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local lastFireTime = 0

-- Ammo state (exposed for HUD)
WeaponClient.ammo = Config.Weapon.MagSize
WeaponClient.maxAmmo = Config.Weapon.MagSize
WeaponClient.reloading = false

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

local function applyHitHighlight(part: BasePart)
	if not part or not part:IsA("BasePart") then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Adornee = part.Parent
	highlight.FillColor = Config.Weapon.HitHighlightColor
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = Config.Weapon.HitHighlightColor
	highlight.OutlineTransparency = 0.3
	highlight.Parent = part

	task.spawn(function()
		task.wait(Config.Weapon.HitHighlightDuration)
		highlight:Destroy()
	end)
end

local function reload()
	if WeaponClient.reloading or WeaponClient.ammo == WeaponClient.maxAmmo then
		return
	end

	WeaponClient.reloading = true

	task.spawn(function()
		task.wait(Config.Weapon.ReloadTime)
		WeaponClient.ammo = WeaponClient.maxAmmo
		WeaponClient.reloading = false
	end)
end

local function fireWeapon()
	if WeaponClient.reloading then
		return
	end

	if WeaponClient.ammo <= 0 then
		reload()
		return
	end

	local now = tick()
	if now - lastFireTime < Config.Weapon.FireRate then
		return
	end
	lastFireTime = now

	local character = getCharacter()
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	WeaponClient.ammo -= 1

	-- Build ray from camera through crosshair (screen center)
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector

	-- Apply tiny spread
	local spreadRad = math.rad(Config.Weapon.SpreadAngle)
	local spreadX = (math.random() - 0.5) * spreadRad
	local spreadY = (math.random() - 0.5) * spreadRad
	direction = (CFrame.new(Vector3.zero, direction) * CFrame.Angles(spreadX, spreadY, 0)).LookVector

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(origin, direction * Config.Weapon.MaxRange, rayParams)

	if result then
		local hitPart = result.Instance
		local hitPosition = result.Position

		local isHeadshot = hitPart.Name == "Head"

		applyHitHighlight(hitPart)

		local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
		remotes:WaitForChild(RemoteNames.WeaponHit):FireServer(hitPart, hitPosition, isHeadshot)
	end
end

function WeaponClient.init()
	local firing = false

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = true
			fireWeapon()
		end
		if input.KeyCode == Enum.KeyCode.R then
			reload()
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = false
		end
	end)

	RunService.Heartbeat:Connect(function()
		if firing then
			fireWeapon()
		end
	end)

	-- Reset ammo on respawn
	player.CharacterAdded:Connect(function()
		WeaponClient.ammo = WeaponClient.maxAmmo
		WeaponClient.reloading = false
	end)
end

return WeaponClient
