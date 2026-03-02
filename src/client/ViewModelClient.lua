--[[
	ViewModelClient — renders first-person weapon model in a ViewportFrame overlay.
	Separate from world/equipped model (HotbarServer handles that).
	ViewportFrame fills screen, camera mirrors workspace camera each frame.
	Weapon renders in ViewportFrame so it never clips through geometry.
	ADS transitions tween between VIEWMODEL_OFFSET and VIEWMODEL_ADS_OFFSET.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local ViewModelClient = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local VM_OFFSET = CFrame.new(
	Config.VIEWMODEL_OFFSET[1],
	Config.VIEWMODEL_OFFSET[2],
	Config.VIEWMODEL_OFFSET[3]
)
local VM_ADS_OFFSET = CFrame.new(
	Config.VIEWMODEL_ADS_OFFSET[1],
	Config.VIEWMODEL_ADS_OFFSET[2],
	Config.VIEWMODEL_ADS_OFFSET[3]
)
local ADS_TIME = Config.ADS_TRANSITION_TIME

-- State
local screenGui = nil
local viewportFrame = nil
local vpCamera = nil
local worldModel = nil
local weaponClone = nil
local isADS = false
local currentOffset = VM_OFFSET
local targetOffset = VM_OFFSET
local transitionAlpha = 0 -- 0 = hip, 1 = ADS
local renderConnection = nil

-- Recoil reference (set during init wiring)
local recoilModule = nil

function ViewModelClient.setRecoilModule(mod)
	recoilModule = mod
end

local function buildViewport()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ViewModelUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local vp = Instance.new("ViewportFrame")
	vp.Name = "WeaponViewport"
	vp.Size = UDim2.new(1, 0, 1, 0)
	vp.BackgroundTransparency = 1
	vp.Parent = gui

	local cam = Instance.new("Camera")
	cam.Parent = vp
	vp.CurrentCamera = cam

	local wm = Instance.new("WorldModel")
	wm.Parent = vp

	screenGui = gui
	viewportFrame = vp
	vpCamera = cam
	worldModel = wm
end

local function clearWeapon()
	if weaponClone then
		weaponClone:Destroy()
		weaponClone = nil
	end
end

local function loadWeapon(itemData)
	clearWeapon()

	if not itemData or not itemData.id then
		return
	end

	-- Clone from ReplicatedStorage.WeaponTemplates (survives pickup/destruction)
	local templates = ReplicatedStorage:FindFirstChild("WeaponTemplates")
	if not templates then
		return
	end

	local template = templates:FindFirstChild(itemData.id)
	if not template then
		return
	end

	local clone = template:Clone()
	clone.Name = "VM_" .. (itemData.name or "Weapon")

	-- Configure all parts
	if clone:IsA("Model") then
		for _, desc in clone:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.Anchored = true
				desc.CanCollide = false
				desc.CastShadow = false
			end
		end
	elseif clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = false
		clone.CastShadow = false
	end

	-- Remove hitbox if present
	local hitbox = clone:FindFirstChild("Hitbox")
	if hitbox then
		hitbox:Destroy()
	end

	clone.Parent = worldModel
	weaponClone = clone

	-- Reset ADS state
	isADS = false
	transitionAlpha = 0
	currentOffset = VM_OFFSET
	targetOffset = VM_OFFSET
end

local function updateWeaponPosition()
	if not weaponClone or not camera then
		return
	end

	-- Get recoil offset
	local recoilX, recoilY = 0, 0
	if recoilModule then
		recoilX, recoilY = recoilModule.getOffset()
	end

	-- Interpolate offset
	local offset = VM_OFFSET:Lerp(VM_ADS_OFFSET, transitionAlpha)

	-- Apply recoil to camera CFrame for viewmodel
	local camCF = camera.CFrame
		* CFrame.Angles(recoilX, recoilY, 0)

	local weaponCF = camCF * offset

	-- Position the weapon
	if weaponClone:IsA("Model") then
		local primary = weaponClone.PrimaryPart or weaponClone:FindFirstChildWhichIsA("BasePart")
		if primary then
			if weaponClone.PrimaryPart then
				weaponClone:PivotTo(weaponCF)
			else
				primary.CFrame = weaponCF
			end
		end
	elseif weaponClone:IsA("BasePart") then
		weaponClone.CFrame = weaponCF
	end

	-- Sync viewport camera to workspace camera
	if vpCamera then
		vpCamera.CFrame = camera.CFrame * CFrame.Angles(recoilX, recoilY, 0)
		vpCamera.FieldOfView = camera.FieldOfView
	end
end

-- ── ADS ──────────────────────────────────────────────────
function ViewModelClient.setADS(adsActive: boolean)
	isADS = adsActive
	targetOffset = isADS and VM_ADS_OFFSET or VM_OFFSET
end

function ViewModelClient.isADS(): boolean
	return isADS
end

-- ── Public ───────────────────────────────────────────────
function ViewModelClient.equipWeapon(itemData)
	loadWeapon(itemData)
end

function ViewModelClient.unequipWeapon()
	clearWeapon()
	isADS = false
	transitionAlpha = 0
end

function ViewModelClient.init()
	buildViewport()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	-- Listen for weapon equip/unequip from HotbarServer
	remotes:WaitForChild(RemoteNames.WeaponEquipped).OnClientEvent:Connect(function(itemData)
		if itemData then
			loadWeapon(itemData)
		end
	end)

	remotes:WaitForChild(RemoteNames.WeaponUnequipped).OnClientEvent:Connect(function()
		clearWeapon()
		isADS = false
		transitionAlpha = 0
	end)

	-- RenderStepped: update weapon position + ADS transition
	renderConnection = RunService.RenderStepped:Connect(function(dt)
		-- ADS alpha interpolation
		local adsTarget = isADS and 1 or 0
		local adsSpeed = dt / math.max(ADS_TIME, 0.01)
		transitionAlpha = transitionAlpha + (adsTarget - transitionAlpha) * math.min(adsSpeed * 4, 1)

		-- Snap when close
		if math.abs(transitionAlpha - adsTarget) < 0.005 then
			transitionAlpha = adsTarget
		end

		updateWeaponPosition()
	end)

	print("[CAG] ViewModelClient initialized (ViewportFrame overlay)")
end

return ViewModelClient
