--[[
	Server bootstrap — creates remote events and initializes all server systems.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)
local LootTableData = require(ReplicatedStorage.Shared.LootTableData)

-- Create all remote events
local remoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents")

for _, name in RemoteNames do
	if not remoteFolder:FindFirstChild(name) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remoteFolder
	end
end

-- ── Weapon templates ──────────────────────────────────────
-- Clone every weapon from Workspace/Weapons into ReplicatedStorage.WeaponTemplates
-- so both server (HotbarServer) and client (ViewModelClient) can clone from them
-- even after the original world instance has been picked up and destroyed.

local wpTemplates = Instance.new("Folder")
wpTemplates.Name = "WeaponTemplates"
wpTemplates.Parent = ReplicatedStorage

-- Build groundModel → itemId lookup
local pathToId = {}
for _, item in LootTableData do
	if item.groundModel and item.isWeapon then
		pathToId[item.groundModel] = item.id
	end
end

local templateCount = 0
local weaponsFolder = workspace:FindFirstChild("Weapons")
if weaponsFolder then
	for _, category in weaponsFolder:GetChildren() do
		if not category:IsA("Folder") then continue end

		for _, weaponFolder in category:GetChildren() do
			if not (weaponFolder:IsA("Folder") or weaponFolder:IsA("Model")) then continue end

			for _, weapon in weaponFolder:GetChildren() do
				if not (weapon:IsA("Model") or weapon:IsA("MeshPart") or weapon:IsA("BasePart")) then
					continue
				end
				if weapon.Name ~= weaponFolder.Name then continue end

				local path = "Weapons/" .. category.Name .. "/" .. weaponFolder.Name .. "/" .. weapon.Name
				local itemId = pathToId[path]
				if itemId then
					-- Set ItemId on the workspace original so clients can identify it
					weapon:SetAttribute("ItemId", itemId)

					-- Clone to ReplicatedStorage as template
					local clone = weapon:Clone()
					clone.Name = itemId
					-- Remove any hitbox from template (HitboxService may have added one)
					local hitbox = clone:FindFirstChild("Hitbox")
					if hitbox then hitbox:Destroy() end
					clone.Parent = wpTemplates
					templateCount = templateCount + 1
				end
			end
		end
	end
end

print("[CAG] WeaponTemplates created (" .. templateCount .. " templates)")

-- ── Data systems ──
local LootTableServer = require(script.LootTableServer)
local InventoryServer = require(script.InventoryServer)

LootTableServer.init()
InventoryServer.init()

-- ── Hitbox + Ground items ──
local HitboxService = require(script.HitboxService)
HitboxService.init()

local GroundItemServer = require(script.GroundItemServer)
GroundItemServer.init()

-- ── Interact system ──
local InteractServer = require(script.InteractServer)
InteractServer.init()

-- ── Hotbar / Equip ──
local HotbarServer = require(script.HotbarServer)
HotbarServer.init()

-- ── Combat ──
local WeaponCombatServer = require(script.WeaponCombatServer)
WeaponCombatServer.init()

print("[CAG] Server initialized")
