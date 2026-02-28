--[[
	SlideController — momentum-based slide on top of default character controller.
	Hold/tap crouch while sprinting to slide. Sliding gradually slows to crouch speed.
	Camera tilts during slide. Cannot slide again until fully stood up.
	Short cooldown prevents spam.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SlideController = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local isSliding = false
local isCrouching = false
local canSlide = true
local slideVelocity = nil
local originalWalkSpeed = 16
local baseHipHeight = nil

local crouchKeyHeld = false

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

local function getHumanoid()
	local character = getCharacter()
	return character:FindFirstChildOfClass("Humanoid")
end

local function standUp()
	local humanoid = getHumanoid()
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	isCrouching = false
	humanoid.WalkSpeed = originalWalkSpeed
	if baseHipHeight then
		humanoid.HipHeight = baseHipHeight
	end

	-- Cooldown starts only after fully standing up
	task.spawn(function()
		task.wait(Config.Slide.Cooldown)
		canSlide = true
	end)
end

local function enterCrouch()
	local humanoid = getHumanoid()
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	isCrouching = true
	humanoid.WalkSpeed = Config.Slide.CrouchSpeed
	if baseHipHeight then
		humanoid.HipHeight = baseHipHeight - 0.8
	end
end

local function endSlideIntoCrouch()
	if not isSliding then
		return
	end

	isSliding = false

	-- Clean up velocity
	if slideVelocity then
		slideVelocity:Destroy()
		slideVelocity = nil
	end

	-- If key still held, transition to crouch; otherwise stand up
	if crouchKeyHeld then
		enterCrouch()
	else
		standUp()
	end
end

local function startSlide()
	if isSliding or isCrouching or not canSlide then
		return
	end

	local character = getCharacter()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end

	local moveDir = humanoid.MoveDirection
	if moveDir.Magnitude < 0.1 then
		return
	end

	isSliding = true
	canSlide = false

	-- Capture base values on first slide
	if not baseHipHeight then
		baseHipHeight = humanoid.HipHeight
	end
	originalWalkSpeed = humanoid.WalkSpeed

	-- Create slide velocity
	slideVelocity = Instance.new("BodyVelocity")
	slideVelocity.MaxForce = Vector3.new(30000, 0, 30000)
	slideVelocity.Velocity = moveDir * originalWalkSpeed * Config.Slide.SpeedMultiplier
	slideVelocity.Parent = rootPart

	-- Lower character for slide
	humanoid.HipHeight = baseHipHeight - 0.8

	-- Slide decay loop — gradually slow to crouch speed then end
	task.spawn(function()
		local elapsed = 0
		while isSliding and elapsed < Config.Slide.Duration do
			local dt = RunService.Heartbeat:Wait()
			elapsed += dt

			if slideVelocity and slideVelocity.Parent then
				slideVelocity.Velocity = slideVelocity.Velocity * Config.Slide.FrictionDecel

				if slideVelocity.Velocity.Magnitude < Config.Slide.MinSpeed then
					break
				end
			else
				break
			end

			-- Camera tilt during slide
			camera = workspace.CurrentCamera
			local progress = elapsed / Config.Slide.Duration
			local rollAngle = math.rad(Config.Slide.CameraTiltAngle) * (1 - progress)
			camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, rollAngle * 0.05)
		end

		endSlideIntoCrouch()
	end)
end

function SlideController.init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Config.Slide.KeyCode then
			crouchKeyHeld = true

			if isSliding then
				-- Already sliding, do nothing
				return
			end

			local humanoid = getHumanoid()
			if not humanoid or humanoid.Health <= 0 then
				return
			end

			-- If moving, try to slide; otherwise enter crouch
			if humanoid.MoveDirection.Magnitude > 0.1 and canSlide then
				startSlide()
			elseif not isCrouching then
				-- Capture base values
				if not baseHipHeight then
					baseHipHeight = humanoid.HipHeight
				end
				originalWalkSpeed = humanoid.WalkSpeed
				enterCrouch()
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if input.KeyCode == Config.Slide.KeyCode then
			crouchKeyHeld = false

			if isSliding then
				-- Let slide finish naturally, endSlideIntoCrouch will call standUp
				-- since crouchKeyHeld is now false
			elseif isCrouching then
				standUp()
			end
		end
	end)

	-- Reset on respawn
	player.CharacterAdded:Connect(function(character)
		isSliding = false
		isCrouching = false
		canSlide = true
		crouchKeyHeld = false
		baseHipHeight = nil

		if slideVelocity then
			slideVelocity:Destroy()
			slideVelocity = nil
		end

		-- Capture hip height once humanoid loads
		local humanoid = character:WaitForChild("Humanoid")
		baseHipHeight = humanoid.HipHeight
		originalWalkSpeed = humanoid.WalkSpeed
	end)
end

return SlideController
