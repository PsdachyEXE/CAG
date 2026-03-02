--[[
	HUDClient — weapon combat HUD overlay.
	Displays: crosshair, ammo counter, fire mode, weapon name,
	reloading indicator, hit markers, kill feed.
	ADS transitions crosshair opacity.
	Exports: updateAmmo, updateFireMode, updateWeaponName, showWeaponHUD,
	         showReloading, showHitMarker, setADS, showFireModeToast, init
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local HUDClient = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── UI references ─────────────────────────────────────────
local screenGui = nil
local crosshairFrame = nil
local ammoLabel = nil
local fireModeLabel = nil
local weaponNameLabel = nil
local reloadingLabel = nil
local hitMarkerImage = nil
local killFeedFrame = nil
local fireModeToast = nil

-- State
local isADS = false
local isHUDVisible = false

-- ── Colours ───────────────────────────────────────────────
local COL_WHITE = Color3.new(1, 1, 1)
local COL_RED = Color3.fromRGB(255, 60, 60)
local COL_GOLD = Color3.fromRGB(255, 215, 0)
local COL_GREY = Color3.fromRGB(180, 180, 180)
local COL_BG = Color3.fromRGB(20, 20, 20)

-- ── Build UI ──────────────────────────────────────────────
local function buildHUD()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WeaponHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui
	screenGui = gui

	-- ── Crosshair ──
	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.Size = UDim2.new(0, 2, 0, 2)
	crosshair.Position = UDim2.new(0.5, -1, 0.5, -1)
	crosshair.BackgroundColor3 = COL_WHITE
	crosshair.BorderSizePixel = 0
	crosshair.Parent = gui
	crosshairFrame = crosshair

	-- Crosshair lines (4 small lines)
	local lineLength = 12
	local gap = 6
	local lineThickness = 2

	-- Top line
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.Size = UDim2.new(0, lineThickness, 0, lineLength)
	top.Position = UDim2.new(0.5, -1, 0.5, -(gap + lineLength))
	top.BackgroundColor3 = COL_WHITE
	top.BorderSizePixel = 0
	top.Parent = gui

	-- Bottom line
	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.Size = UDim2.new(0, lineThickness, 0, lineLength)
	bottom.Position = UDim2.new(0.5, -1, 0.5, gap)
	bottom.BackgroundColor3 = COL_WHITE
	bottom.BorderSizePixel = 0
	bottom.Parent = gui

	-- Left line
	local left = Instance.new("Frame")
	left.Name = "Left"
	left.Size = UDim2.new(0, lineLength, 0, lineThickness)
	left.Position = UDim2.new(0.5, -(gap + lineLength), 0.5, -1)
	left.BackgroundColor3 = COL_WHITE
	left.BorderSizePixel = 0
	left.Parent = gui

	-- Right line
	local right = Instance.new("Frame")
	right.Name = "Right"
	right.Size = UDim2.new(0, lineLength, 0, lineThickness)
	right.Position = UDim2.new(0.5, gap, 0.5, -1)
	right.BackgroundColor3 = COL_WHITE
	right.BorderSizePixel = 0
	right.Parent = gui

	-- Store crosshair parts for ADS transition
	crosshairFrame = {crosshair, top, bottom, left, right}

	-- ── Bottom-right panel: Ammo + Fire mode + Weapon name ──
	local panelFrame = Instance.new("Frame")
	panelFrame.Name = "WeaponPanel"
	panelFrame.Size = UDim2.new(0, 220, 0, 80)
	panelFrame.Position = UDim2.new(1, -240, 1, -100)
	panelFrame.BackgroundColor3 = COL_BG
	panelFrame.BackgroundTransparency = 0.4
	panelFrame.BorderSizePixel = 0
	panelFrame.Parent = gui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 6)
	panelCorner.Parent = panelFrame

	local panelPad = Instance.new("UIPadding")
	panelPad.PaddingLeft = UDim.new(0, 12)
	panelPad.PaddingRight = UDim.new(0, 12)
	panelPad.PaddingTop = UDim.new(0, 8)
	panelPad.PaddingBottom = UDim.new(0, 8)
	panelPad.Parent = panelFrame

	-- Weapon name (top)
	local wName = Instance.new("TextLabel")
	wName.Name = "WeaponName"
	wName.Size = UDim2.new(1, 0, 0, 18)
	wName.Position = UDim2.new(0, 0, 0, 0)
	wName.BackgroundTransparency = 1
	wName.Font = Enum.Font.GothamBold
	wName.TextSize = 14
	wName.TextColor3 = COL_GREY
	wName.TextXAlignment = Enum.TextXAlignment.Left
	wName.Text = ""
	wName.Parent = panelFrame
	weaponNameLabel = wName

	-- Ammo display (center, large)
	local ammo = Instance.new("TextLabel")
	ammo.Name = "Ammo"
	ammo.Size = UDim2.new(1, 0, 0, 30)
	ammo.Position = UDim2.new(0, 0, 0, 20)
	ammo.BackgroundTransparency = 1
	ammo.Font = Enum.Font.GothamBold
	ammo.TextSize = 28
	ammo.TextColor3 = COL_WHITE
	ammo.TextXAlignment = Enum.TextXAlignment.Left
	ammo.Text = "30 / 30"
	ammo.Parent = panelFrame
	ammoLabel = ammo

	-- Fire mode (bottom)
	local fMode = Instance.new("TextLabel")
	fMode.Name = "FireMode"
	fMode.Size = UDim2.new(1, 0, 0, 16)
	fMode.Position = UDim2.new(0, 0, 1, -16)
	fMode.BackgroundTransparency = 1
	fMode.Font = Enum.Font.Gotham
	fMode.TextSize = 12
	fMode.TextColor3 = COL_GREY
	fMode.TextXAlignment = Enum.TextXAlignment.Left
	fMode.Text = "SEMI"
	fMode.Parent = panelFrame
	fireModeLabel = fMode

	-- ── Reloading indicator (center screen) ──
	local reloading = Instance.new("TextLabel")
	reloading.Name = "Reloading"
	reloading.Size = UDim2.new(0, 200, 0, 30)
	reloading.Position = UDim2.new(0.5, -100, 0.6, 0)
	reloading.BackgroundTransparency = 1
	reloading.Font = Enum.Font.GothamBold
	reloading.TextSize = 18
	reloading.TextColor3 = COL_WHITE
	reloading.TextTransparency = 1
	reloading.Text = "RELOADING..."
	reloading.Parent = gui
	reloadingLabel = reloading

	-- ── Hit marker (center, X shape via text) ──
	local hitMarker = Instance.new("TextLabel")
	hitMarker.Name = "HitMarker"
	hitMarker.Size = UDim2.new(0, 40, 0, 40)
	hitMarker.Position = UDim2.new(0.5, -20, 0.5, -20)
	hitMarker.BackgroundTransparency = 1
	hitMarker.Font = Enum.Font.GothamBold
	hitMarker.TextSize = 24
	hitMarker.TextColor3 = COL_WHITE
	hitMarker.TextTransparency = 1
	hitMarker.Text = "X"
	hitMarker.Parent = gui
	hitMarkerImage = hitMarker

	-- ── Fire mode toast (center-top, brief notification) ──
	local toast = Instance.new("TextLabel")
	toast.Name = "FireModeToast"
	toast.Size = UDim2.new(0, 200, 0, 30)
	toast.Position = UDim2.new(0.5, -100, 0.35, 0)
	toast.BackgroundColor3 = COL_BG
	toast.BackgroundTransparency = 0.4
	toast.Font = Enum.Font.GothamBold
	toast.TextSize = 16
	toast.TextColor3 = COL_WHITE
	toast.TextTransparency = 1
	toast.Text = ""
	toast.Parent = gui
	fireModeToast = toast

	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 6)
	toastCorner.Parent = toast

	-- ── Kill feed (top-right) ──
	local kf = Instance.new("Frame")
	kf.Name = "KillFeed"
	kf.Size = UDim2.new(0, 350, 0, 200)
	kf.Position = UDim2.new(1, -370, 0, 20)
	kf.BackgroundTransparency = 1
	kf.Parent = gui
	killFeedFrame = kf

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 4)
	layout.Parent = kf

	-- Initially hidden
	gui.Enabled = false
end

-- ── Public API ────────────────────────────────────────────

function HUDClient.updateAmmo(current: number, max: number)
	if ammoLabel then
		ammoLabel.Text = tostring(current) .. " / " .. tostring(max)
		-- Flash red when low
		if current <= math.floor(max * 0.25) then
			ammoLabel.TextColor3 = COL_RED
		else
			ammoLabel.TextColor3 = COL_WHITE
		end
	end
end

function HUDClient.updateFireMode(mode: string)
	if fireModeLabel then
		fireModeLabel.Text = string.upper(mode or "SEMI")
	end
end

function HUDClient.updateWeaponName(name: string)
	if weaponNameLabel then
		weaponNameLabel.Text = name or ""
	end
end

function HUDClient.showWeaponHUD(visible: boolean)
	isHUDVisible = visible
	if screenGui then
		screenGui.Enabled = visible
	end
end

function HUDClient.showReloading(show: boolean)
	if not reloadingLabel then
		return
	end
	if show then
		reloadingLabel.TextTransparency = 0
		-- Pulse animation
		local tween = TweenService:Create(reloadingLabel, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			TextTransparency = 0.5,
		})
		tween:Play()
		reloadingLabel:SetAttribute("PulseTween", true)
	else
		-- Stop pulse and hide
		reloadingLabel:SetAttribute("PulseTween", false)
		TweenService:Create(reloadingLabel, TweenInfo.new(0.2), {
			TextTransparency = 1,
		}):Play()
	end
end

function HUDClient.showHitMarker(isHeadshot: boolean)
	if not hitMarkerImage then
		return
	end

	hitMarkerImage.TextColor3 = isHeadshot and COL_GOLD or COL_WHITE
	hitMarkerImage.Text = isHeadshot and "+" or "X"
	hitMarkerImage.TextTransparency = 0

	-- Quick fade out
	task.spawn(function()
		task.wait(0.15)
		TweenService:Create(hitMarkerImage, TweenInfo.new(0.2), {
			TextTransparency = 1,
		}):Play()
	end)
end

function HUDClient.setADS(adsActive: boolean)
	isADS = adsActive

	-- Fade crosshair lines during ADS
	if crosshairFrame and type(crosshairFrame) == "table" then
		local targetTransp = isADS and 0.7 or 0
		for _, part in crosshairFrame do
			TweenService:Create(part, TweenInfo.new(0.2), {
				BackgroundTransparency = targetTransp,
			}):Play()
		end
	end
end

function HUDClient.showFireModeToast(mode: string)
	if not fireModeToast then
		return
	end

	fireModeToast.Text = "FIRE MODE: " .. string.upper(mode or "SEMI")
	fireModeToast.TextTransparency = 0
	fireModeToast.BackgroundTransparency = 0.4

	task.spawn(function()
		task.wait(1.2)
		TweenService:Create(fireModeToast, TweenInfo.new(0.4), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
	end)
end

-- ── Kill feed ─────────────────────────────────────────────
local killFeedOrder = 0

local function addKillFeedEntry(killerName, victimName, weaponName)
	if not killFeedFrame then
		return
	end

	killFeedOrder = killFeedOrder + 1

	local entry = Instance.new("TextLabel")
	entry.Name = "Kill_" .. killFeedOrder
	entry.Size = UDim2.new(1, 0, 0, 22)
	entry.BackgroundColor3 = COL_BG
	entry.BackgroundTransparency = 0.5
	entry.Font = Enum.Font.Gotham
	entry.TextSize = 13
	entry.TextColor3 = COL_WHITE
	entry.TextXAlignment = Enum.TextXAlignment.Right
	entry.Text = killerName .. "  [" .. (weaponName or "?") .. "]  " .. victimName
	entry.LayoutOrder = killFeedOrder
	entry.Parent = killFeedFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = entry

	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.Parent = entry

	-- Highlight if local player is killer
	if killerName == (player.DisplayName or player.Name) then
		entry.TextColor3 = COL_GOLD
	end

	-- Fade out after delay
	task.spawn(function()
		task.wait(5)
		TweenService:Create(entry, TweenInfo.new(0.5), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
		task.wait(0.6)
		entry:Destroy()
	end)

	-- Cap entries (keep last 5)
	local children = killFeedFrame:GetChildren()
	local entries = {}
	for _, child in children do
		if child:IsA("TextLabel") then
			table.insert(entries, child)
		end
	end
	if #entries > 5 then
		table.sort(entries, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = 1, #entries - 5 do
			entries[i]:Destroy()
		end
	end
end

-- ── Init ──────────────────────────────────────────────────
function HUDClient.init()
	buildHUD()

	-- Listen for PlayerKilled
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	remotes:WaitForChild(RemoteNames.PlayerKilled).OnClientEvent:Connect(function(killerName, victimName, weaponName)
		addKillFeedEntry(killerName, victimName, weaponName)
	end)

	print("[CAG] HUDClient initialized")
end

return HUDClient
