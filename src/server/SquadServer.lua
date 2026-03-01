--[[
	SquadServer — manages player squads (max 4).
	Create, invite, accept, decline, leave.
	Disables friendly fire within squad. Shared extraction.
	Squad data wiped on round end.
	Exports: getSquad, isSquadMate, createSquad, invitePlayer,
	         acceptInvite, leaveSquad, resetAllSquads
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local SquadServer = {}

local squads = {}            -- [squadID] = { leader, members = {player, ...} }
local playerToSquad = {}     -- [player] = squadID
local pendingInvites = {}    -- [targetPlayer] = { from = player, squadID = id, expires = tick }
local nextSquadID = 1

local function getRemotes()
	return ReplicatedStorage:FindFirstChild("RemoteEvents")
end

local function broadcastSquadUpdate(squadID)
	local squad = squads[squadID]
	if not squad then
		return
	end

	local remotes = getRemotes()
	if not remotes then
		return
	end

	local updateRemote = remotes:FindFirstChild(RemoteNames.SquadUpdate)
	if not updateRemote then
		return
	end

	local memberNames = {}
	for _, member in squad.members do
		if member.Parent then
			table.insert(memberNames, member.Name)
		end
	end

	local data = {
		squadID = squadID,
		leader = squad.leader.Name,
		members = memberNames,
	}

	for _, member in squad.members do
		if member.Parent then
			updateRemote:FireClient(member, data)
		end
	end
end

function SquadServer.createSquad(player: Player): number?
	-- Already in a squad?
	if playerToSquad[player] then
		return nil
	end

	local squadID = nextSquadID
	nextSquadID = nextSquadID + 1

	squads[squadID] = {
		leader = player,
		members = { player },
	}
	playerToSquad[player] = squadID

	broadcastSquadUpdate(squadID)
	print("[CAG] " .. player.Name .. " created squad #" .. squadID)
	return squadID
end

function SquadServer.invitePlayer(inviter: Player, targetName: string): boolean
	local squadID = playerToSquad[inviter]
	if not squadID then
		return false
	end

	local squad = squads[squadID]
	if not squad then
		return false
	end

	-- Only leader can invite
	if squad.leader ~= inviter then
		return false
	end

	-- Check max size
	if #squad.members >= Config.Squad.MaxSize then
		return false
	end

	-- Find target player
	local target = nil
	for _, plr in Players:GetPlayers() do
		if plr.Name == targetName then
			target = plr
			break
		end
	end

	if not target or playerToSquad[target] then
		return false
	end

	-- Send invite
	pendingInvites[target] = {
		from = inviter,
		squadID = squadID,
		expires = tick() + 30, -- 30 second timeout
	}

	local remotes = getRemotes()
	if remotes then
		local inviteRemote = remotes:FindFirstChild(RemoteNames.SquadInviteReceived)
		if inviteRemote then
			inviteRemote:FireClient(target, {
				from = inviter.Name,
				squadID = squadID,
			})
		end
	end

	print("[CAG] " .. inviter.Name .. " invited " .. targetName .. " to squad #" .. squadID)
	return true
end

function SquadServer.acceptInvite(player: Player): boolean
	local invite = pendingInvites[player]
	if not invite then
		return false
	end

	-- Check expiry
	if tick() > invite.expires then
		pendingInvites[player] = nil
		return false
	end

	local squad = squads[invite.squadID]
	if not squad then
		pendingInvites[player] = nil
		return false
	end

	-- Check max size
	if #squad.members >= Config.Squad.MaxSize then
		pendingInvites[player] = nil
		return false
	end

	-- Add to squad
	table.insert(squad.members, player)
	playerToSquad[player] = invite.squadID
	pendingInvites[player] = nil

	broadcastSquadUpdate(invite.squadID)
	print("[CAG] " .. player.Name .. " joined squad #" .. invite.squadID)
	return true
end

function SquadServer.leaveSquad(player: Player)
	local squadID = playerToSquad[player]
	if not squadID then
		return
	end

	local squad = squads[squadID]
	if not squad then
		playerToSquad[player] = nil
		return
	end

	-- Remove from members
	for i, member in squad.members do
		if member == player then
			table.remove(squad.members, i)
			break
		end
	end
	playerToSquad[player] = nil

	-- If empty, disband
	if #squad.members == 0 then
		squads[squadID] = nil
	else
		-- Transfer leadership if leader left
		if squad.leader == player then
			squad.leader = squad.members[1]
		end
		broadcastSquadUpdate(squadID)
	end

	-- Notify the leaving player
	local remotes = getRemotes()
	if remotes then
		local updateRemote = remotes:FindFirstChild(RemoteNames.SquadUpdate)
		if updateRemote then
			updateRemote:FireClient(player, nil) -- nil = no squad
		end
	end

	print("[CAG] " .. player.Name .. " left squad #" .. squadID)
end

function SquadServer.getSquad(player: Player)
	local squadID = playerToSquad[player]
	if not squadID then
		return nil
	end
	return squads[squadID]
end

function SquadServer.isSquadMate(p1: Player, p2: Player): boolean
	local sq1 = playerToSquad[p1]
	local sq2 = playerToSquad[p2]
	if not sq1 or not sq2 then
		return false
	end
	return sq1 == sq2
end

function SquadServer.getSquadMembers(player: Player): { Player }
	local squadID = playerToSquad[player]
	if not squadID or not squads[squadID] then
		return {}
	end
	return squads[squadID].members
end

function SquadServer.resetAllSquads()
	squads = {}
	playerToSquad = {}
	pendingInvites = {}
	print("[CAG] All squads reset")
end

-- Fire squad health updates periodically
local function startHealthBroadcast()
	task.spawn(function()
		while true do
			local remotes = getRemotes()
			local healthRemote = remotes and remotes:FindFirstChild(RemoteNames.SquadHealthUpdate)

			for squadID, squad in squads do
				if healthRemote then
					local healthData = {}
					for _, member in squad.members do
						if member.Parent and member.Character then
							local hum = member.Character:FindFirstChildOfClass("Humanoid")
							if hum then
								table.insert(healthData, {
									name = member.Name,
									health = hum.Health,
									maxHealth = hum.MaxHealth,
								})
							end
						end
					end

					for _, member in squad.members do
						if member.Parent then
							healthRemote:FireClient(member, healthData)
						end
					end
				end
			end

			task.wait(0.5)
		end
	end)
end

function SquadServer.init()
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	-- Create squad
	remotes:WaitForChild(RemoteNames.CreateSquad).OnServerEvent:Connect(function(player)
		SquadServer.createSquad(player)
	end)

	-- Invite
	remotes:WaitForChild(RemoteNames.InviteToSquad).OnServerEvent:Connect(function(player, targetName)
		if type(targetName) == "string" then
			SquadServer.invitePlayer(player, targetName)
		end
	end)

	-- Accept invite
	remotes:WaitForChild(RemoteNames.AcceptSquadInvite).OnServerEvent:Connect(function(player)
		SquadServer.acceptInvite(player)
	end)

	-- Decline invite
	remotes:WaitForChild(RemoteNames.DeclineSquadInvite).OnServerEvent:Connect(function(player)
		pendingInvites[player] = nil
	end)

	-- Leave squad
	remotes:WaitForChild(RemoteNames.LeaveSquad).OnServerEvent:Connect(function(player)
		SquadServer.leaveSquad(player)
	end)

	-- Cleanup on player leaving
	Players.PlayerRemoving:Connect(function(player)
		SquadServer.leaveSquad(player)
		pendingInvites[player] = nil
	end)

	startHealthBroadcast()

	print("[CAG] SquadServer initialized")
end

return SquadServer
