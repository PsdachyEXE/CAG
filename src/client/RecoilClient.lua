--[[
	RecoilClient — applies camera recoil kick on weapon fire.
	Each shot adds upward + random horizontal offset to camera.
	Recovery tweens camera back after firing stops.
	Recoil stacks on rapid fire, capped at 3x single kick.
	Exports: applyRecoil(recoilKick), resetRecoil(), init
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local RecoilClient = {}

local RECOVERY_TIME = Config.RECOIL_RECOVERY_TIME
local KICK_RECOVERY = Config.CAMERA_KICK_RECOVERY

-- State
local recoilOffsetX = 0 -- pitch (up/down)
local recoilOffsetY = 0 -- yaw (left/right)
local targetOffsetX = 0
local targetOffsetY = 0
local currentKickMax = 0 -- 3x cap based on current weapon
local isFiring = false
local lastFireTick = 0

function RecoilClient.applyRecoil(recoilKick: number)
	currentKickMax = recoilKick * 3
	isFiring = true
	lastFireTick = tick()

	-- Upward kick (negative X = look up)
	local kickX = -recoilKick
	-- Random horizontal offset
	local kickY = (math.random() - 0.5) * 0.6 * recoilKick

	targetOffsetX = math.max(targetOffsetX + kickX, -currentKickMax)
	targetOffsetY = targetOffsetY + kickY

	-- Clamp Y too
	targetOffsetY = math.clamp(targetOffsetY, -currentKickMax, currentKickMax)
end

function RecoilClient.resetRecoil()
	targetOffsetX = 0
	targetOffsetY = 0
	isFiring = false
end

function RecoilClient.getOffset(): (number, number)
	return recoilOffsetX, recoilOffsetY
end

function RecoilClient.init()
	RunService.RenderStepped:Connect(function(dt)
		local timeSinceFire = tick() - lastFireTick

		-- If we haven't fired recently, start recovery
		if timeSinceFire > KICK_RECOVERY then
			isFiring = false
		end

		if not isFiring then
			-- Recover toward zero
			local recoverySpeed = dt / math.max(RECOVERY_TIME, 0.01)
			targetOffsetX = targetOffsetX + (0 - targetOffsetX) * math.min(recoverySpeed * 3, 1)
			targetOffsetY = targetOffsetY + (0 - targetOffsetY) * math.min(recoverySpeed * 3, 1)

			-- Snap to zero when close
			if math.abs(targetOffsetX) < 0.001 then targetOffsetX = 0 end
			if math.abs(targetOffsetY) < 0.001 then targetOffsetY = 0 end
		end

		-- Smooth interpolation toward target
		local lerpSpeed = math.min(dt * 20, 1)
		recoilOffsetX = recoilOffsetX + (targetOffsetX - recoilOffsetX) * lerpSpeed
		recoilOffsetY = recoilOffsetY + (targetOffsetY - recoilOffsetY) * lerpSpeed
	end)

	print("[CAG] RecoilClient initialized")
end

return RecoilClient
