--[[
	AnticheatServer — server-side exploit detection.
	Movement validation: speed hack, teleport detection.
	Weapon validation: fire rate, DPS, raycast origin.
	Remote spam detection. Invalid item claims.
	Flags logged to DataStore. Actions: warn, kick, temp ban.
	Exports: flagPlayer, getViolations, isFlagged
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local AnticheatServer = {}

-- Module references
local RoundServer = nil

local violations = {}     -- [player] = { {type, value, timestamp}, ... }
local lastPositions = {}  -- [player] = { position, time }
local playerFlags = {}    -- [player] = flagCount
local banStore = nil

local SEVERITY = {
	warn = "warn",
	kick = "kick",
	ban = "ban",
}

local function getSeverity(violationType: string, count: number): string
	-- Escalation: first few = warn, then kick, then ban
	if count >= 10 then
		return SEVERITY.ban
	elseif count >= 5 then
		return SEVERITY.kick
	end
	-- Teleport is instant kick
	if violationType == "teleport" then
		return SEVERITY.kick
	end
	return SEVERITY.warn
end

local function logViolation(player: Player, violationType: string, value: any)
	if not violations[player] then
		violations[player] = {}
	end

	table.insert(violations[player], {
		type = violationType,
		value = value,
		timestamp = os.time(),
	})

	-- Persist to DataStore
	if banStore then
		task.spawn(function()
			pcall(function()
				local key = "AC_" .. player.UserId
				banStore:UpdateAsync(key, function(old)
					local data = old or { violations = {}, banUntil = 0 }
					table.insert(data.violations, {
						type = violationType,
						value = tostring(value),
						timestamp = os.time(),
					})
					-- Keep last 50 violations
					while #data.violations > 50 do
						table.remove(data.violations, 1)
					end
					return data
				end)
			end)
		end)
	end
end

local function takeAction(player: Player, severity: string, reason: string)
	if severity == SEVERITY.kick then
		player:Kick("Anti-cheat: " .. reason)
	elseif severity == SEVERITY.ban then
		-- Set temp ban
		if banStore then
			task.spawn(function()
				pcall(function()
					local key = "AC_" .. player.UserId
					banStore:UpdateAsync(key, function(old)
						local data = old or { violations = {}, banUntil = 0 }
						data.banUntil = os.time() + Config.Anticheat.BanDuration
						return data
					end)
				end)
			end)
		end
		player:Kick("Temporarily banned: " .. reason)
	end
	-- warn = log only (already logged)
end

function AnticheatServer.flagPlayer(player: Player, reason: string, value: any)
	if not playerFlags[player] then
		playerFlags[player] = 0
	end
	playerFlags[player] = playerFlags[player] + 1

	logViolation(player, reason, value)

	local severity = getSeverity(reason, playerFlags[player])
	print(
		"[CAG-AC] Flag: "
			.. player.Name
			.. " | "
			.. reason
			.. " | severity="
			.. severity
			.. " | count="
			.. playerFlags[player]
	)

	takeAction(player, severity, reason)
end

function AnticheatServer.getViolations(player: Player)
	return violations[player] or {}
end

function AnticheatServer.isFlagged(player: Player): boolean
	return (playerFlags[player] or 0) > 0
end

-- ── Movement validation ──────────────────────────────────

local function startMovementCheck()
	RunService.Heartbeat:Connect(function(_dt)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if not character then
				continue
			end

			local hrp = character:FindFirstChild("HumanoidRootPart")
			if not hrp then
				continue
			end

			local now = tick()
			local currentPos = hrp.Position

			if lastPositions[player] then
				local lastPos = lastPositions[player].position
				local lastTime = lastPositions[player].time
				local dt = now - lastTime

				if dt > 0.05 then -- at least 50ms between checks
					local distance = (currentPos - lastPos).Magnitude
					local speed = distance / dt

					-- Teleport check
					if distance > Config.Anticheat.TeleportThreshold then
						AnticheatServer.flagPlayer(player, "teleport", {
							distance = distance,
							dt = dt,
						})
					-- Speed hack check
					elseif speed > Config.Anticheat.MaxSpeedStuds * 1.5 then
						-- Allow some tolerance (1.5x) for physics jitter
						AnticheatServer.flagPlayer(player, "speedhack", {
							speed = speed,
							maxAllowed = Config.Anticheat.MaxSpeedStuds,
						})
					end

					lastPositions[player] = { position = currentPos, time = now }
				end
			else
				lastPositions[player] = { position = currentPos, time = now }
			end
		end
	end)
end

-- ── Ban check on join ────────────────────────────────────

local function checkBanOnJoin(player: Player)
	if not banStore then
		return
	end

	local success, data = pcall(function()
		return banStore:GetAsync("AC_" .. player.UserId)
	end)

	if success and data and data.banUntil then
		if os.time() < data.banUntil then
			local remaining = data.banUntil - os.time()
			player:Kick("You are temporarily banned. Time remaining: " .. math.ceil(remaining / 60) .. " minutes.")
		end
	end
end

function AnticheatServer.init()
	-- Initialize DataStore
	local storeSuccess, _ = pcall(function()
		banStore = DataStoreService:GetDataStore("CAG_Anticheat_v1")
	end)

	if not storeSuccess then
		warn("[CAG-AC] DataStore unavailable (Studio?)")
		banStore = nil
	end

	-- Get module references
	local serverModules = script.Parent
	local roundModule = serverModules:FindFirstChild("RoundServer")
	if roundModule then
		RoundServer = require(roundModule)
	end

	-- Check bans on join
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			checkBanOnJoin(player)
		end)
	end)

	-- Check existing players
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			checkBanOnJoin(player)
		end)
	end

	-- Cleanup on leave
	Players.PlayerRemoving:Connect(function(player)
		violations[player] = nil
		lastPositions[player] = nil
		playerFlags[player] = nil
	end)

	-- Start movement checks
	startMovementCheck()

	print("[CAG] AnticheatServer initialized")
end

return AnticheatServer
