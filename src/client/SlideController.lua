--[[
	SlideController — adds a slide mechanic on top of the default Roblox character controller.
	Press LeftControl while moving to slide. Applies a velocity boost in the move direction,
	tilts the camera, and has a cooldown.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SlideController = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local isSliding = false
local canSlide = true
local slideVelocity = nil -- BodyVelocity instance
local slideTween = nil

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

local function getMoveDirection(): Vector3
	local character = getCharacter()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid.MoveDirection
	end
	return Vector3.zero
end

local function startSlide()
	if isSliding or not canSlide then
		return
	end

	local character = getCharacter()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end

	local moveDir = getMoveDirection()
	if moveDir.Magnitude < 0.1 then
		return
	end

	isSliding = true
	canSlide = false

	-- Store original walk speed
	local originalSpeed = humanoid.WalkSpeed

	-- Create slide velocity
	slideVelocity = Instance.new("BodyVelocity")
	slideVelocity.MaxForce = Vector3.new(30000, 0, 30000)
	slideVelocity.Velocity = moveDir * originalSpeed * Config.Slide.SpeedMultiplier
	slideVelocity.Parent = rootPart

	-- Lower the character slightly for visual effect
	humanoid.HipHeight = humanoid.HipHeight - 0.8

	-- Camera tilt
	local tiltCF = CFrame.Angles(0, 0, math.rad(Config.Slide.CameraTiltAngle))
	slideTween = TweenService:Create(camera, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {})

	-- Slide decay
	task.spawn(function()
		local elapsed = 0
		local dt
		while isSliding and elapsed < Config.Slide.Duration do
			dt = RunService.Heartbeat:Wait()
			elapsed += dt

			-- Decelerate
			if slideVelocity and slideVelocity.Parent then
				slideVelocity.Velocity = slideVelocity.Velocity * Config.Slide.FrictionDecel

				if slideVelocity.Velocity.Magnitude < Config.Slide.MinSpeed then
					break
				end
			else
				break
			end

			-- Apply camera roll
			local progress = elapsed / Config.Slide.Duration
			local rollAngle = math.rad(Config.Slide.CameraTiltAngle) * (1 - progress)
			camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, rollAngle * 0.05)
		end

		endSlide()
	end)
end

function endSlide()
	if not isSliding then
		return
	end

	isSliding = false

	local character = getCharacter()
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	-- Clean up velocity
	if slideVelocity then
		slideVelocity:Destroy()
		slideVelocity = nil
	end

	-- Reset hip height
	if humanoid then
		humanoid.HipHeight = humanoid.HipHeight + 0.8
	end

	-- Cooldown
	task.spawn(function()
		task.wait(Config.Slide.Cooldown)
		canSlide = true
	end)
end

function SlideController.init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Config.Slide.KeyCode then
			startSlide()
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if input.KeyCode == Config.Slide.KeyCode and isSliding then
			endSlide()
		end
	end)

	-- Reset on death
	player.CharacterAdded:Connect(function(_character)
		isSliding = false
		canSlide = true
		if slideVelocity then
			slideVelocity:Destroy()
			slideVelocity = nil
		end
	end)
end

return SlideController
