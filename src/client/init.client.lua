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

SlideController.init()
WeaponClient.init()
DamageNumbers.init()
ExtractionClient.init()

print("[CAG] Client initialized")
