--[[
	RecoilClient — applies camera recoil kick on weapon fire.
	Each shot kicks camera up + random horizontal immediately.
	Recovery lerps camera back after firing stops using exponential decay.
	Recoil stacks on rapid fire, capped at 3x single kick.
	Exports: applyRecoil(recoilKick), resetRecoil(), getOffset(), init
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local RecoilClient = {}

local RECOVERY_TIME = Config.RECOIL_RECOVERY_TIME
local KICK_RECOVERY = Config.CAMERA_KICK_RECOVERY

-- Cumulative recoil offset applied to camera (in degrees)
local recoilOffsetX = 0 -- pitch (up = negative)
local recoilOffsetY = 0 -- yaw
local currentKickMax = 0
local isFiring = false
local lastFireTick = 0

function RecoilClient.applyRecoil(recoilKick: number)
	currentKickMax = recoilKick * 3
	isFiring = true
	lastFireTick = tick()

	-- Kick amounts per spec
	local kickX = -recoilKick                               -- upward
	local kickY = (math.random() - 0.5) * recoilKick * 0.3 -- slight random yaw

	-- Clamp cumulative accumulation
	local newOffsetX = math.max(recoilOffsetX + kickX, -currentKickMax)
	local newOffsetY = math.clamp(recoilOffsetY + kickY, -currentKickMax, currentKickMax)

	local deltaX = newOffsetX - recoilOffsetX
	local deltaY = newOffsetY - recoilOffsetY

	recoilOffsetX = newOffsetX
	recoilOffsetY = newOffsetY

	-- Apply kick immediately to camera
	local cam = workspace.CurrentCamera
	cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(deltaX * 2), math.rad(deltaY), 0)
end

function RecoilClient.resetRecoil()
	recoilOffsetX = 0
	recoilOffsetY = 0
	isFiring = false
end

function RecoilClient.getOffset(): (number, number)
	return recoilOffsetX, recoilOffsetY
end

function RecoilClient.init()
	RunService.RenderStepped:Connect(function(dt)
		local timeSinceFire = tick() - lastFireTick

		if timeSinceFire > KICK_RECOVERY then
			isFiring = false
		end

		-- Recovery: exponential decay toward zero, apply delta to camera each frame
		if not isFiring and (math.abs(recoilOffsetX) > 0.001 or math.abs(recoilOffsetY) > 0.001) then
			local lerpFactor = 1 - math.exp(-dt / math.max(RECOVERY_TIME, 0.01))

			local prevX = recoilOffsetX
			local prevY = recoilOffsetY

			recoilOffsetX = recoilOffsetX + (0 - recoilOffsetX) * lerpFactor
			recoilOffsetY = recoilOffsetY + (0 - recoilOffsetY) * lerpFactor

			-- Snap to zero when close
			if math.abs(recoilOffsetX) < 0.001 then recoilOffsetX = 0 end
			if math.abs(recoilOffsetY) < 0.001 then recoilOffsetY = 0 end

			-- Apply the recovery delta (negative of how much offset was reduced)
			local deltaX = recoilOffsetX - prevX
			local deltaY = recoilOffsetY - prevY

			local cam = workspace.CurrentCamera
			cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(deltaX * 2), math.rad(deltaY), 0)
		end
	end)

	print("[CAG] RecoilClient initialized")
end

return RecoilClient
