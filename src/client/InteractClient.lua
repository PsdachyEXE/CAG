--[[
	InteractClient — E-key interact system.
	Shows a BillboardGui prompt on the nearest tagged LootContainer
	within INTERACT_RANGE. Only one prompt visible at a time.
	Fires ContainerInteract to server on E press.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RemoteNames = require(ReplicatedStorage.Shared.RemoteNames)

local InteractClient = {}

local player = Players.LocalPlayer
local INTERACT_RANGE = Config.Interact.INTERACT_RANGE
local FADE_TIME = 0.15

local currentTarget = nil -- the container currently showing prompt
local promptGui = nil     -- the single reusable BillboardGui
local isFading = false

-- Set of containers the server told us are looted
local lootedContainers = {} -- [Instance] = true

local function createPrompt(): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "InteractPrompt"
	billboard.Size = UDim2.new(0, 48, 0, 48)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = INTERACT_RANGE + 2
	billboard.Enabled = false

	-- Background frame
	local bg = Instance.new("Frame")
	bg.Name = "BG"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(26, 26, 46) -- #1A1A2E
	bg.BackgroundTransparency = 0.25
	bg.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = bg

	-- UIStroke with gradient for fading border effect
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Border"
	stroke.Color = Color3.new(1, 1, 1) -- #FFFFFF
	stroke.Thickness = 2
	stroke.Parent = bg

	-- Gradient on the stroke for faded corners
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),    -- corner start (faded)
		NumberSequenceKeypoint.new(0.15, 0),    -- side (opaque)
		NumberSequenceKeypoint.new(0.85, 0),    -- side (opaque)
		NumberSequenceKeypoint.new(1, 0.6),     -- corner end (faded)
	})
	gradient.Parent = stroke

	-- "E" text
	local eLabel = Instance.new("TextLabel")
	eLabel.Name = "KeyLabel"
	eLabel.Size = UDim2.new(1, 0, 1, 0)
	eLabel.BackgroundTransparency = 1
	eLabel.Text = "E"
	eLabel.Font = Enum.Font.FredokaOne
	eLabel.TextSize = 24
	eLabel.TextColor3 = Color3.new(1, 1, 1)
	eLabel.Parent = bg

	return billboard
end

local function getContainerPart(container: Instance): BasePart?
	if container:IsA("Model") then
		return container.PrimaryPart or container:FindFirstChildWhichIsA("BasePart")
	elseif container:IsA("BasePart") then
		return container
	end
	return nil
end

local function showPrompt(container)
	if currentTarget == container then
		return
	end

	local part = getContainerPart(container)
	if not part then
		return
	end

	currentTarget = container

	-- Reparent the billboard to the container's part
	promptGui.Adornee = part
	promptGui.Parent = part
	promptGui.Enabled = true

	-- Fade in
	local bg = promptGui:FindFirstChild("BG")
	if bg then
		bg.BackgroundTransparency = 1
		local eLabel = bg:FindFirstChild("KeyLabel")
		if eLabel then
			eLabel.TextTransparency = 1
		end
		local border = bg:FindFirstChild("Border")
		if border then
			border.Transparency = 1
		end

		TweenService:Create(bg, TweenInfo.new(FADE_TIME), { BackgroundTransparency = 0.25 }):Play()
		if eLabel then
			TweenService:Create(eLabel, TweenInfo.new(FADE_TIME), { TextTransparency = 0 }):Play()
		end
		if border then
			TweenService:Create(border, TweenInfo.new(FADE_TIME), { Transparency = 0 }):Play()
		end
	end
end

local function hidePrompt()
	if not currentTarget then
		return
	end

	isFading = true
	local fadingTarget = currentTarget
	currentTarget = nil

	local bg = promptGui:FindFirstChild("BG")
	if bg then
		local eLabel = bg:FindFirstChild("KeyLabel")
		local border = bg:FindFirstChild("Border")

		TweenService:Create(bg, TweenInfo.new(FADE_TIME), { BackgroundTransparency = 1 }):Play()
		if eLabel then
			TweenService:Create(eLabel, TweenInfo.new(FADE_TIME), { TextTransparency = 1 }):Play()
		end
		if border then
			TweenService:Create(border, TweenInfo.new(FADE_TIME), { Transparency = 1 }):Play()
		end
	end

	task.spawn(function()
		task.wait(FADE_TIME)
		-- Only disable if we haven't already shown a new prompt
		if currentTarget == nil then
			promptGui.Enabled = false
		end
		isFading = false
	end)
end

local function findNearestContainer(): (Instance?, number?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil, nil
	end

	local playerPos = hrp.Position
	local nearest = nil
	local nearestDist = INTERACT_RANGE + 1

	for _, container in CollectionService:GetTagged("LootContainer") do
		-- Skip looted containers
		if lootedContainers[container] then
			continue
		end

		local part = getContainerPart(container)
		if not part then
			continue
		end

		local dist = (playerPos - part.Position).Magnitude
		if dist <= INTERACT_RANGE and dist < nearestDist then
			nearest = container
			nearestDist = dist
		end
	end

	return nearest, nearestDist
end

function InteractClient.init()
	promptGui = createPrompt()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local interactRemote = remotes:WaitForChild(RemoteNames.ContainerInteract)

	-- Proximity check loop (0.1s interval via RunService)
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum = accum + dt
		if accum < 0.1 then
			return
		end
		accum = 0

		local nearest, _ = findNearestContainer()

		if nearest then
			showPrompt(nearest)
		elseif currentTarget then
			hidePrompt()
		end
	end)

	-- E key to interact
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.E then
			if currentTarget then
				interactRemote:FireServer(currentTarget)
			end
		end
	end)

	-- Listen for container looted (remove prompt eligibility)
	local lootedRemote = remotes:WaitForChild(RemoteNames.ContainerLooted)
	lootedRemote.OnClientEvent:Connect(function(container)
		if container then
			lootedContainers[container] = true
			-- If we're showing prompt on this container, hide it
			if currentTarget == container then
				hidePrompt()
			end
		end
	end)

	-- Listen for interact failed
	local failRemote = remotes:WaitForChild(RemoteNames.InteractFailed)
	failRemote.OnClientEvent:Connect(function(reason)
		if reason == "INVENTORY_FULL" then
			-- Fire notification via NotificationClient remote
			local notifRemote = remotes:FindFirstChild(RemoteNames.ShowNotification)
			if notifRemote then
				-- NotificationClient listens on this remote
				-- We fire it locally by calling the module directly if available
			end
			-- Use the ShowNotification pattern: server fires it,
			-- but for client-only feedback we can use a local approach
			-- Simplest: just fire to self via the existing pattern
			-- Actually, InteractServer already fires InteractFailed.
			-- We handle it here by showing a notification toast.
			local NotificationClient = nil
			local ok, mod = pcall(function()
				return require(script.Parent.NotificationClient)
			end)
			if ok and mod and mod.show then
				mod.show("warning", "Inventory Full")
			end
		end
	end)

	-- Reset looted set on round start
	remotes:WaitForChild(RemoteNames.RoundStateChanged).OnClientEvent:Connect(function(state)
		if state == "Waiting" or state == "Active" then
			lootedContainers = {}
		end
	end)

	print("[CAG] InteractClient initialized")
end

return InteractClient
