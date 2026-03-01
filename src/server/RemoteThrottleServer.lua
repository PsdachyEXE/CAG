--[[
	RemoteThrottleServer — rate-limits all client→server remote events.
	Wraps existing OnServerEvent connections with throttle checks.
	Excess calls logged to AnticheatServer and silently ignored.
	Exports: wrapRemote, getThrottleLimit
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local RemoteThrottleServer = {}

-- Module reference
local AnticheatServer = nil

-- Per-player, per-remote call tracking: [player] = { [remoteName] = { count, resetTime } }
local callTracking = {}

-- Custom limits per remote (override default)
local customLimits = {}

local function getLimit(remoteName: string): number
	if customLimits[remoteName] then
		return customLimits[remoteName]
	end
	return Config.RemoteThrottle.DefaultLimit
end

local function checkThrottle(player: Player, remoteName: string): boolean
	if not callTracking[player] then
		callTracking[player] = {}
	end

	local playerTrack = callTracking[player]
	local now = tick()

	if not playerTrack[remoteName] then
		playerTrack[remoteName] = { count = 0, resetTime = now + 1 }
	end

	local track = playerTrack[remoteName]

	-- Reset counter every second
	if now >= track.resetTime then
		track.count = 0
		track.resetTime = now + 1
	end

	track.count = track.count + 1

	local limit = getLimit(remoteName)
	if track.count > limit then
		-- Flag with anticheat
		if AnticheatServer then
			AnticheatServer.flagPlayer(player, "remote_spam", {
				remote = remoteName,
				count = track.count,
				limit = limit,
			})
		end
		return false -- throttled
	end

	return true -- allowed
end

function RemoteThrottleServer.wrapRemote(remoteName: string, callback: (Player, ...any) -> ())
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remotes then
		return
	end

	local remote = remotes:FindFirstChild(remoteName)
	if not remote then
		return
	end

	remote.OnServerEvent:Connect(function(player, ...)
		if checkThrottle(player, remoteName) then
			callback(player, ...)
		end
	end)
end

function RemoteThrottleServer.getThrottleLimit(remoteName: string): number
	return getLimit(remoteName)
end

function RemoteThrottleServer.init()
	-- Set custom limits
	customLimits[RemoteNames.WeaponHit] = Config.RemoteThrottle.WeaponFireLimit
	customLimits[RemoteNames.WeaponFire] = Config.RemoteThrottle.WeaponFireLimit
	customLimits[RemoteNames.ContainerInteract] = Config.RemoteThrottle.ContainerInteractLimit
	customLimits[RemoteNames.CreateSquad] = Config.RemoteThrottle.SquadActionLimit
	customLimits[RemoteNames.InviteToSquad] = Config.RemoteThrottle.SquadActionLimit
	customLimits[RemoteNames.AcceptSquadInvite] = Config.RemoteThrottle.SquadActionLimit
	customLimits[RemoteNames.DeclineSquadInvite] = Config.RemoteThrottle.SquadActionLimit
	customLimits[RemoteNames.LeaveSquad] = Config.RemoteThrottle.SquadActionLimit

	-- Get AnticheatServer reference (may not exist yet)
	local serverModules = script.Parent
	local acModule = serverModules:FindFirstChild("AnticheatServer")
	if acModule then
		AnticheatServer = require(acModule)
	end

	-- Cleanup on player leave
	Players.PlayerRemoving:Connect(function(player)
		callTracking[player] = nil
	end)

	print("[CAG] RemoteThrottleServer initialized")
end

return RemoteThrottleServer
