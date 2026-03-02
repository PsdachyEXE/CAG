--[[
	WeaponCombatClient — handles all client-side weapon combat logic.
	Firing (auto/semi/burst), reloading, ADS, fire mode switching, weapon swap.
	Sends WeaponFired to server for hit detection. Manages ammo state.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local WeaponCombatClient = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Module references (set via wiring in bootstrap)
local ViewModelClient = nil
local RecoilClient = nil
local HUDClient = nil
local InventoryOpenCheck = nil

-- ── State ────────────────────────────────────────────────
local currentWeapon = nil     -- itemData table
local currentAmmo = 0
local isReloading = false
local isADS = false
local currentFireMode = nil   -- string: "auto"/"semi"/"burst"
local fireModeIndex = 1
local isSwapping = false
local lastFireTime = 0
local isFiringAuto = false    -- is LMB held for auto fire
local autoFireThread = nil

-- ── Module setters ───────────────────────────────────────
function WeaponCombatClient.setViewModelClient(mod)
	ViewModelClient = mod
end

function WeaponCombatClient.setRecoilClient(mod)
	RecoilClient = mod
end

function WeaponCombatClient.setHUDClient(mod)
	HUDClient = mod
end

function WeaponCombatClient.setInventoryOpenCheck(fn)
	InventoryOpenCheck = fn
end

-- ── Helpers ──────────────────────────────────────────────
local function inputDisabled(): boolean
	if isReloading or isSwapping then
		return true
	end
	if InventoryOpenCheck and InventoryOpenCheck() then
		return true
	end
	return false
end

local function getWeaponStat(key, default)
	if currentWeapon and currentWeapon[key] ~= nil then
		return currentWeapon[key]
	end
	return default
end

-- ── Mouse lock ───────────────────────────────────────────
local function setMouseLocked(locked: boolean)
	if locked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end

function WeaponCombatClient.onInventoryOpened()
	setMouseLocked(false)
end

function WeaponCombatClient.onInventoryClosed()
	if currentWeapon then
		setMouseLocked(true)
	end
end

-- ── Fire logic ───────────────────────────────────────────
local function calculateSpreadDirection(baseDir: Vector3, spreadAngle: number): Vector3
	if spreadAngle <= 0 then
		return baseDir.Unit
	end

	-- Random offset within cone
	local angle = spreadAngle * math.random()
	local theta = math.random() * math.pi * 2

	local right = baseDir:Cross(Vector3.new(0, 1, 0))
	if right.Magnitude < 0.01 then
		right = baseDir:Cross(Vector3.new(1, 0, 0))
	end
	right = right.Unit

	local up = right:Cross(baseDir).Unit

	local offset = (right * math.cos(theta) + up * math.sin(theta)) * math.sin(angle)
	return (baseDir.Unit + offset).Unit
end

local function fireBullet()
	if not currentWeapon then
		return
	end
	if currentAmmo <= 0 then
		return
	end

	-- Rate of fire check
	local now = tick()
	local fireInterval = 60 / getWeaponStat("fireRate", 600)
	if now - lastFireTime < fireInterval * 0.9 then
		return
	end
	lastFireTime = now

	-- Decrement ammo
	currentAmmo = currentAmmo - 1

	-- Apply recoil BEFORE reading direction: camera kicks first so
	-- LookVector naturally reflects the kicked angle.
	if RecoilClient then
		RecoilClient.applyRecoil(getWeaponStat("recoilKick", 0.1))
	end

	-- Calculate origin and direction AFTER recoil kick
	if not camera then
		camera = workspace.CurrentCamera
	end
	local origin = camera.CFrame.Position
	local baseDir = camera.CFrame.LookVector

	-- Spread
	local spreadVal = isADS and getWeaponStat("adsSpread", 0.01) or getWeaponStat("spread", 0.03)

	-- Fire remote
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remotes then
		return
	end
	local fireRemote = remotes:FindFirstChild(RemoteNames.WeaponFired)
	if not fireRemote then
		return
	end

	local pelletCount = getWeaponStat("pellets", nil)

	if pelletCount and pelletCount > 1 then
		-- Shotgun: multiple pellets
		local pelletSpread = isADS and getWeaponStat("adsSpread", 5) or getWeaponStat("pelletSpread", 10)
		-- Convert degrees to radians for pellet spread
		local spreadRad = math.rad(pelletSpread)
		local direction = calculateSpreadDirection(baseDir, spreadRad)
		fireRemote:FireServer(origin, direction, currentWeapon.id, isADS, pelletCount)
	else
		-- Single bullet
		local direction = calculateSpreadDirection(baseDir, spreadVal)
		fireRemote:FireServer(origin, direction, currentWeapon.id, isADS, nil)
	end

	-- Update HUD
	if HUDClient then
		HUDClient.updateAmmo(currentAmmo, getWeaponStat("magSize", 30))
	end
end

local function triggerReload()
	if not currentWeapon then
		return
	end
	if isReloading then
		return
	end
	local magSize = getWeaponStat("magSize", 30)
	if currentAmmo >= magSize then
		return
	end

	isReloading = true

	-- Fire to server
	local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remotes then
		local reloadRemote = remotes:FindFirstChild(RemoteNames.ReloadStarted)
		if reloadRemote then
			reloadRemote:FireServer()
		end
	end

	-- Update HUD
	if HUDClient then
		HUDClient.showReloading(true)
	end

	-- Wait reload time
	local reloadTime = getWeaponStat("reloadTime", 2.0)
	task.spawn(function()
		task.wait(reloadTime)
		if currentWeapon then
			currentAmmo = getWeaponStat("magSize", 30)
			isReloading = false

			if HUDClient then
				HUDClient.showReloading(false)
				HUDClient.updateAmmo(currentAmmo, getWeaponStat("magSize", 30))
			end
		end
	end)
end

-- ── Auto fire loop ───────────────────────────────────────
local function startAutoFire()
	if isFiringAuto then
		return
	end
	isFiringAuto = true

	autoFireThread = task.spawn(function()
		while isFiringAuto and currentWeapon and not inputDisabled() do
			if currentAmmo > 0 then
				fireBullet()
				local fireInterval = 60 / getWeaponStat("fireRate", 600)
				task.wait(fireInterval)
			else
				triggerReload()
				break
			end
		end
		isFiringAuto = false
	end)
end

local function stopAutoFire()
	isFiringAuto = false
end

-- ── Burst fire ───────────────────────────────────────────
local function fireBurst()
	local burstCount = getWeaponStat("burstCount", 3)

	task.spawn(function()
		for _ = 1, burstCount do
			if not currentWeapon or inputDisabled() then
				break
			end
			if currentAmmo > 0 then
				fireBullet()
				task.wait(Config.BURST_DELAY)
			else
				triggerReload()
				break
			end
		end
	end)
end

-- ── ADS ──────────────────────────────────────────────────
local function enterADS()
	if isADS or not currentWeapon then
		return
	end
	isADS = true

	if ViewModelClient then
		ViewModelClient.setADS(true)
	end

	-- FOV tween
	if camera then
		TweenService:Create(camera, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FieldOfView = Config.DEFAULT_FOV - Config.ADS_FOV_REDUCTION,
		}):Play()
	end

	if HUDClient then
		HUDClient.setADS(true)
	end
end

local function exitADS()
	if not isADS then
		return
	end
	isADS = false

	if ViewModelClient then
		ViewModelClient.setADS(false)
	end

	-- FOV tween back
	if camera then
		TweenService:Create(camera, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FieldOfView = Config.DEFAULT_FOV,
		}):Play()
	end

	if HUDClient then
		HUDClient.setADS(false)
	end
end

-- ── Fire mode switch ─────────────────────────────────────
local function cycleFireMode()
	if not currentWeapon then
		return
	end
	local modes = currentWeapon.fireMode
	if not modes or #modes <= 1 then
		return
	end

	fireModeIndex = fireModeIndex + 1
	if fireModeIndex > #modes then
		fireModeIndex = 1
	end
	currentFireMode = modes[fireModeIndex]

	if HUDClient then
		HUDClient.updateFireMode(currentFireMode)
		HUDClient.showFireModeToast(currentFireMode)
	end
end

-- ── Weapon equip/unequip ─────────────────────────────────
function WeaponCombatClient.onWeaponEquipped(itemData)
	if not itemData or not itemData.isWeapon then
		WeaponCombatClient.onWeaponUnequipped()
		return
	end

	-- Lock mouse whenever a weapon is equipped
	setMouseLocked(true)

	-- Swap delay if already had a weapon
	if currentWeapon and not isSwapping then
		isSwapping = true
		stopAutoFire()
		exitADS()

		task.spawn(function()
			task.wait(Config.WEAPON_SWAP_DELAY)
			currentWeapon = itemData
			currentAmmo = itemData.magSize or 30
			fireModeIndex = 1
			currentFireMode = itemData.fireMode and itemData.fireMode[1] or "semi"
			isReloading = false
			isSwapping = false

			if HUDClient then
				HUDClient.updateAmmo(currentAmmo, itemData.magSize or 30)
				HUDClient.updateFireMode(currentFireMode)
				HUDClient.updateWeaponName(itemData.name)
				HUDClient.showWeaponHUD(true)
			end
		end)
		return
	end

	-- First equip (no swap delay)
	currentWeapon = itemData
	currentAmmo = itemData.magSize or 30
	fireModeIndex = 1
	currentFireMode = itemData.fireMode and itemData.fireMode[1] or "semi"
	isReloading = false

	if HUDClient then
		HUDClient.updateAmmo(currentAmmo, itemData.magSize or 30)
		HUDClient.updateFireMode(currentFireMode)
		HUDClient.updateWeaponName(itemData.name)
		HUDClient.showWeaponHUD(true)
	end
end

function WeaponCombatClient.onWeaponUnequipped()
	currentWeapon = nil
	currentAmmo = 0
	isReloading = false
	isADS = false
	isFiringAuto = false
	stopAutoFire()

	-- Unlock mouse on unequip
	setMouseLocked(false)

	if RecoilClient then
		RecoilClient.resetRecoil()
	end

	if HUDClient then
		HUDClient.showWeaponHUD(false)
	end

	-- Reset FOV
	if camera then
		TweenService:Create(camera, TweenInfo.new(0.2), {
			FieldOfView = Config.DEFAULT_FOV,
		}):Play()
	end
end

function WeaponCombatClient.getCurrentWeapon()
	return currentWeapon
end

function WeaponCombatClient.isWeaponADS(): boolean
	return isADS
end

-- ── Init ─────────────────────────────────────────────────
function WeaponCombatClient.init()
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

	-- WeaponEquipped from HotbarServer
	remotes:WaitForChild(RemoteNames.WeaponEquipped).OnClientEvent:Connect(function(itemData)
		WeaponCombatClient.onWeaponEquipped(itemData)
	end)

	-- WeaponUnequipped from HotbarServer
	remotes:WaitForChild(RemoteNames.WeaponUnequipped).OnClientEvent:Connect(function()
		WeaponCombatClient.onWeaponUnequipped()
	end)

	-- HitConfirmed from WeaponCombatServer
	remotes:WaitForChild(RemoteNames.HitConfirmed).OnClientEvent:Connect(function(isHeadshot, damage, hitPosition)
		if HUDClient then
			HUDClient.showHitMarker(isHeadshot)
		end
	end)

	-- ReloadComplete from server
	remotes:WaitForChild(RemoteNames.ReloadComplete).OnClientEvent:Connect(function()
		-- Server confirms reload; client already handles timing locally
	end)

	-- ── Input ────────────────────────────────────────────
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if not currentWeapon or inputDisabled() then
			return
		end

		-- Left click: fire
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if currentFireMode == "auto" then
				startAutoFire()
			elseif currentFireMode == "semi" then
				if currentAmmo > 0 then
					fireBullet()
				else
					triggerReload()
				end
			elseif currentFireMode == "burst" then
				if currentAmmo > 0 then
					fireBurst()
				else
					triggerReload()
				end
			end
		end

		-- Right click: ADS
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			enterADS()
		end

		-- R: reload
		if input.KeyCode == Enum.KeyCode.R then
			triggerReload()
		end

		-- V: cycle fire mode
		if input.KeyCode == Enum.KeyCode.V then
			cycleFireMode()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		-- Release LMB: stop auto fire
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			stopAutoFire()
		end

		-- Release RMB: exit ADS
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			exitADS()
		end
	end)

	-- Wire inventory open/close to mouse lock (BindableEvents if present)
	local bindables = ReplicatedStorage:FindFirstChild("BindableEvents")
	if bindables then
		local invOpened = bindables:FindFirstChild("InventoryOpened")
		if invOpened then
			invOpened.Event:Connect(function()
				WeaponCombatClient.onInventoryOpened()
			end)
		end
		local invClosed = bindables:FindFirstChild("InventoryClosed")
		if invClosed then
			invClosed.Event:Connect(function()
				WeaponCombatClient.onInventoryClosed()
			end)
		end
	end

	print("[CAG] WeaponCombatClient initialized")
end

return WeaponCombatClient
