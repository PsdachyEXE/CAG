--[[
	WeaponClient — hitscan raycast weapon with ammo, reload camera tilt,
	and weapon sway on movement. Click to fire, R to reload. Hold-to-fire.
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

-- Sway state
local swayOffsetX = 0
local swayOffsetY = 0
local reloadTiltProgress = 0

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
	reloadTiltProgress = 0

	task.spawn(function()
		-- Animate reload tilt
		local elapsed = 0
		local reloadTime = Config.Weapon.ReloadTime
		while elapsed < reloadTime and WeaponClient.reloading do
			local dt = RunService.Heartbeat:Wait()
			elapsed += dt
			local t = elapsed / reloadTime
			-- Tilt down in first half, back up in second half
			if t < 0.5 then
				reloadTiltProgress = t * 2 -- 0 -> 1
			else
				reloadTiltProgress = (1 - t) * 2 -- 1 -> 0
			end
		end

		reloadTiltProgress = 0
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

	-- Build ray from camera through crosshair
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector

	-- Apply spread
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

	-- Weapon sway + reload tilt on RenderStepped
	RunService.RenderStepped:Connect(function(dt)
		camera = workspace.CurrentCamera

		local character = player.Character
		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		-- Movement-based sway
		local moveDir = humanoid.MoveDirection
		local targetSwayX = 0
		local targetSwayY = 0

		if moveDir.Magnitude > 0.1 then
			-- Project move direction into camera-local space
			local camRight = camera.CFrame.RightVector
			local camUp = camera.CFrame.UpVector
			local lateralDot = moveDir:Dot(camRight)
			local forwardDot = moveDir:Dot(camera.CFrame.LookVector)

			targetSwayX = -lateralDot * Config.Weapon.SwayAmount
			-- Subtle vertical bob
			targetSwayY = math.sin(tick() * Config.Weapon.SwaySpeed) * Config.Weapon.SwayAmount * 0.3
		end

		-- Smoothly interpolate sway
		local returnSpeed = Config.Weapon.SwayReturnSpeed * dt
		swayOffsetX = swayOffsetX + (targetSwayX - swayOffsetX) * math.min(returnSpeed, 1)
		swayOffsetY = swayOffsetY + (targetSwayY - swayOffsetY) * math.min(returnSpeed, 1)

		-- Apply sway
		local swayCF = CFrame.Angles(
			math.rad(swayOffsetY),
			math.rad(swayOffsetX),
			0
		)

		-- Reload tilt
		local reloadCF = CFrame.Angles(
			math.rad(Config.Weapon.ReloadTiltAngle * reloadTiltProgress),
			0,
			0
		)

		camera.CFrame = camera.CFrame * swayCF * reloadCF
	end)

	-- Reset ammo on respawn
	player.CharacterAdded:Connect(function()
		WeaponClient.ammo = WeaponClient.maxAmmo
		WeaponClient.reloading = false
		reloadTiltProgress = 0
		swayOffsetX = 0
		swayOffsetY = 0
	end)
end

return WeaponClient
