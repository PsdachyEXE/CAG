--[[
	HitboxService — generates invisible hitbox parts for weapon models.
	On startup: iterates Workspace/Weapons/ recursively, creates bounding-box
	hitbox Parts welded to each weapon, tags with CollectionService.
	Exports: generateHitbox(weaponModel), init
]]

local CollectionService = game:GetService("CollectionService")

local HitboxService = {}

local HITBOX_TAG = "WeaponHitbox"
local WEAPON_TAG = "WorldWeapon"

local function getPrimaryPart(model)
	if model:IsA("Model") then
		return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	elseif model:IsA("BasePart") then
		return model
	end
	return nil
end

function HitboxService.generateHitbox(weaponModel)
	-- Don't double-generate
	if weaponModel:FindFirstChild("Hitbox") then
		return weaponModel:FindFirstChild("Hitbox")
	end

	local primary = getPrimaryPart(weaponModel)
	if not primary then
		return nil
	end

	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.Anchored = false
	hitbox.CanQuery = true -- raycasts can hit it
	hitbox.Massless = true

	-- Size from bounding box
	if weaponModel:IsA("Model") then
		local cf, size = weaponModel:GetBoundingBox()
		hitbox.Size = size
		hitbox.CFrame = cf
	else
		hitbox.Size = primary.Size
		hitbox.CFrame = primary.CFrame
	end

	hitbox.Parent = weaponModel

	-- Weld to primary part
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hitbox
	weld.Part1 = primary
	weld.Parent = hitbox

	-- Tag
	CollectionService:AddTag(hitbox, HITBOX_TAG)

	-- Tag parent weapon
	if not CollectionService:HasTag(weaponModel, WEAPON_TAG) then
		CollectionService:AddTag(weaponModel, WEAPON_TAG)
	end

	return hitbox
end

function HitboxService.init()
	local weaponsFolder = workspace:FindFirstChild("Weapons")
	if not weaponsFolder then
		print("[CAG] HitboxService: no Weapons folder in Workspace, skipping")
		return
	end

	local count = 0

	-- Iterate categories (AR, SMG, PISTOL, etc.)
	for _, category in weaponsFolder:GetChildren() do
		if not category:IsA("Folder") then
			continue
		end

		for _, weapon in category:GetChildren() do
			if weapon:IsA("Model") or weapon:IsA("MeshPart") or weapon:IsA("BasePart") then
				HitboxService.generateHitbox(weapon)
				count = count + 1
			end
		end
	end

	print("[CAG] HitboxService initialized (" .. count .. " weapon hitboxes generated)")
end

return HitboxService
