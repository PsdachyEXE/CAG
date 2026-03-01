--[[
	Client bootstrap — initializes all client-side systems.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for remotes to be created by server
ReplicatedStorage:WaitForChild("RemoteEvents")
ReplicatedStorage:WaitForChild("Shared")

local SlideController = require(script.SlideController)
local WeaponClient = require(script.WeaponClient)
local DamageNumbers = require(script.DamageNumbers)
local ExtractionClient = require(script.ExtractionClient)
local CombatFeedback = require(script.CombatFeedback)
local HUDClient = require(script.HUDClient)

local SquadClient = require(script.SquadClient)
local SpectatorClient = require(script.SpectatorClient)
local KillFeedClient = require(script.KillFeedClient)
local LeaderboardClient = require(script.LeaderboardClient)

local InventoryClient = require(script.InventoryClient)
local NotificationClient = require(script.NotificationClient)
local AirdropClient = require(script.AirdropClient)
local MainMenuClient = require(script.MainMenuClient)

SlideController.init()
WeaponClient.init()
DamageNumbers.init()
ExtractionClient.init()
CombatFeedback.init()
HUDClient.init(WeaponClient)
SquadClient.init()
SpectatorClient.init()
KillFeedClient.init()
LeaderboardClient.init()
InventoryClient.init()
NotificationClient.init()
AirdropClient.init()
MainMenuClient.init()

print("[CAG] Client initialized")
