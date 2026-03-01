--[[
	InteractClient — E-key interact system for LootContainer tagged objects.
	Shows a 48x48 BillboardGui prompt on the nearest container within range.
	Only one prompt visible at a time. Fires ContainerInteract on E press.
	0.5s cooldown after firing to prevent spam.
	No longer handles loot directly — InventoryClient manages the UI panel.
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
local INTERACT_RANGE = Config.INTERACT_RANGE
local COOLDOWN = Config.INTERACT_COOLDOWN
local FADE_TIME = 0.15

local currentTarget = nil   -- container currently showing prompt
local promptGui = nil        -- single reusable BillboardGui
local onCooldown = false
local emptySet = {}          -- [Instance] = true, containers with no loot left

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
	bg.BackgroundColor3 = Color3.fromRGB(26, 26, 46)
	bg.BackgroundTransparency = 0.25
	bg.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = bg

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Border"
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2
	stroke.Parent = bg

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.15, 0),
		NumberSequenceKeypoint.new(0.85, 0),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	gradient.Parent = stroke

	local bgGradient = Instance.new("UIGradient")
	bgGradient.Name = "BGGradient"
	bgGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.3, 0),
		NumberSequenceKeypoint.new(0.7, 0),
		NumberSequenceKeypoint.new(1, 0.7),
	})
	bgGradient.Parent = bg

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
	promptGui.Adornee = part
	promptGui.Parent = part
	promptGui.Enabled = true

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

	local fadingFrom = currentTarget
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
		if currentTarget == nil then
			promptGui.Enabled = false
		end
	end)
end

local function findNearest(): Instance?
	local character = player.Character
	if not character then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end

	local pos = hrp.Position
	local nearest = nil
	local nearestDist = INTERACT_RANGE + 1

	for _, container in CollectionService:GetTagged("LootContainer") do
		if emptySet[container] then
			continue
		end

		local part = getContainerPart(container)
		if not part then
			continue
		end

		local dist = (pos - part.Position).Magnitude
		if dist <= INTERACT_RANGE and dist < nearestDist then
			nearest = container
			nearestDist = dist
		end
	end

	return nearest
end

-- Called when container is fully emptied
function InteractClient.markContainerEmpty(container: Instance)
	if container then
		emptySet[container] = true
		if currentTarget == container then
			hidePrompt()
		end
	end
end

function InteractClient.init()
	promptGui = createPrompt()

	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local interactRemote = remotes:WaitForChild(RemoteNames.ContainerInteract)

	-- Proximity check every 0.1s
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum = accum + dt
		if accum < 0.1 then
			return
		end
		accum = 0

		local nearest = findNearest()
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
			if currentTarget and not onCooldown then
				onCooldown = true
				interactRemote:FireServer(currentTarget)

				task.spawn(function()
					task.wait(COOLDOWN)
					onCooldown = false
				end)
			end
		end
	end)

	-- InteractFailed — clear cooldown state
	remotes:WaitForChild(RemoteNames.InteractFailed).OnClientEvent:Connect(function(_reason)
		-- InventoryClient handles the visual feedback
	end)

	print("[CAG] InteractClient initialized")
end

return InteractClient
