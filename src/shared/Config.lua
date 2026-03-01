local Config = {}

-- Sliding
Config.Slide = {
	Duration = 0.8,
	SpeedMultiplier = 1.8,
	Cooldown = 1.0,
	CameraTiltAngle = 8,
	FrictionDecel = 0.92,
	MinSpeed = 4,
	CrouchSpeed = 8,
	KeyCode = Enum.KeyCode.LeftControl,
}

-- Weapons
Config.Weapon = {
	MaxRange = 300,
	Damage = 25,
	FireRate = 0.15,
	HeadshotMultiplier = 2,
	MagSize = 30,
	ReloadTime = 1.8,
	ReloadTiltAngle = 12,
	HitHighlightColor = Color3.fromRGB(255, 80, 80),
	HitHighlightDuration = 0.15,
	DamageNumberLifetime = 1.0,
	DamageNumberRiseSpeed = 30,
	DamageNumberDrift = 20,
	SpreadAngle = 1.5,
	HitMarkerDuration = 0.12,
	HitMarkerSize = 24,
	ScreenShakePerDamage = 0.025,
	ScreenShakeMin = 0.15,
	ScreenShakeMax = 0.8,
	ScreenShakeDuration = 0.15,
	KillFlashDuration = 0.2,
	SwayAmount = 0.3,
	SwaySpeed = 8,
	SwayReturnSpeed = 6,
}

-- AI
Config.AI = {
	DetectionRange = 80,
	AttackRange = 4,
	AttackDamage = 15,
	AttackCooldown = 1.0,
	MoveSpeed = 16,
	Health = 100,
	PathfindingInterval = 0.5,
	FlankAngle = 70,
	FlankDistance = 15,
	FlankLOSTimeout = 3,
	StaggerDuration = 0.4,
	StaggerSpeedMult = 0.2,
	DeathScatterForce = 40,
	DeathScatterLifetime = 2,
	WaveInterval = 30,
	WaveBaseSize = 3,
	WaveGrowth = 1,
	SpeedScalePerWave = 0.5,
	StuckTimeout = 2,
	StuckThreshold = 1,
	SeparationDistance = 5,
	SeparationForce = 8,
	SpawnPositions = {
		Vector3.new(50, 0, 50),
		Vector3.new(-50, 0, 50),
		Vector3.new(50, 0, -50),
		Vector3.new(-50, 0, -50),
		Vector3.new(70, 0, 0),
		Vector3.new(-70, 0, 0),
		Vector3.new(0, 0, 70),
		Vector3.new(0, 0, -70),
	},
}

-- Extraction
Config.Extraction = {
	Duration = 5,
	ZoneRadius = 12,
	ZoneColor = Color3.fromRGB(0, 230, 120),
	PulseMin = 0.9,
	PulseMax = 1.1,
	PulseSpeed = 2,
	ZonePosition = Vector3.new(0, 0.2, 60),
}

-- Round
Config.Round = {
	EndScreenDuration = 10,
	MatchDuration = 300, -- 5 minutes
	ExtractionPhasePercent = 0.80,
	MinPlayers = 1, -- 1 for testing, 2 for real
	IntermissionDuration = 10,
	XPParticipation = 50,
	XPPerKill = 15,
	XPExtraction = 100,
	XPPerWave = 10,
}

-- HUD
Config.HUD = {
	HealthBarWidth = 260,
	HealthBarHeight = 28,
	HealthHighColor = Color3.fromRGB(80, 255, 80),
	HealthMidColor = Color3.fromRGB(255, 200, 40),
	HealthLowColor = Color3.fromRGB(255, 50, 50),
	HealthLowThreshold = 0.3,
	HealthMidThreshold = 0.6,
	AmmoFlashColor = Color3.fromRGB(255, 60, 60),
	MinimapSize = 140,
}

-- Loot
Config.Loot = {
	ContainerWeights = { Common = 55, Uncommon = 25, Rare = 12, Epic = 6, Legendary = 2 },
	AIDropWeights = { Uncommon = 60, Rare = 25, Epic = 10, Legendary = 5 },
	AirdropWeights = { Rare = 50, Epic = 35, Legendary = 15 },
	AIDropChance = 0.40,
}

-- Airdrop
Config.Airdrop = {
	TriggerPercent = 0.60,
	ETA = 15,
	CrateLifetime = 90,
	MapBoundsMin = Vector3.new(-100, 0, -100),
	MapBoundsMax = Vector3.new(100, 0, 100),
	CrateDropHeight = 100,
}

-- Inventory
Config.Inventory = {
	MaxVolatileSlots = 4,
}

-- Interact
Config.Interact = {
	INTERACT_RANGE = 6,
	SERVER_RANGE = 8,
	LOOT_LOCK_TIME = 0.5,
}

-- Demo mode
Config.isDemoMode = true

-- Squad
Config.Squad = {
	MaxSize = 4,
	XPBonus = 0.10,
}

-- Spawn
Config.Spawn = {
	MinSpawnDistance = 20,
	SquadSpawnRadius = 30,
	SpawnPositions = {
		Vector3.new(80, 5, 80),
		Vector3.new(-80, 5, 80),
		Vector3.new(80, 5, -80),
		Vector3.new(-80, 5, -80),
		Vector3.new(100, 5, 0),
		Vector3.new(-100, 5, 0),
		Vector3.new(0, 5, 100),
		Vector3.new(0, 5, -100),
		Vector3.new(60, 5, 60),
		Vector3.new(-60, 5, 60),
		Vector3.new(60, 5, -60),
		Vector3.new(-60, 5, -60),
	},
}

-- Kill Feed
Config.KillFeed = {
	MaxEntries = 5,
	EntryLifetime = 5,
}

-- Anticheat
Config.Anticheat = {
	MaxSpeedStuds = 32,
	TeleportThreshold = 200,
	RemoteSpamLimit = 20,
	WeaponFireRateLimit = 15,
	BanDuration = 3600,
	MaxRetries = 3,
}

-- Remote Throttle
Config.RemoteThrottle = {
	DefaultLimit = 20,
	WeaponFireLimit = 15,
	ContainerInteractLimit = 2,
	SquadActionLimit = 5,
}

-- Progression
Config.Progression = {
	LevelCap = 50,
	XPCurveBase = 100,
	XPCurveExponent = 1.4,
}

-- Notification
Config.Notification = {
	MaxVisible = 4,
	HoldDuration = 3,
	SlideInDuration = 0.2,
	SlideOutDuration = 0.15,
}

-- UI Styling
Config.UIStyle = {
	PanelBG = Color3.fromRGB(26, 26, 46),
	PanelBGTransparency = 0.15,
	PanelBorderRed = Color3.fromRGB(233, 69, 96),
	PanelBorderBlue = Color3.fromRGB(15, 52, 96),
	TextPrimary = Color3.fromRGB(255, 255, 255),
	TextSecondary = Color3.fromRGB(160, 160, 176),
	Positive = Color3.fromRGB(76, 175, 80),
	Negative = Color3.fromRGB(244, 67, 54),
	Highlight = Color3.fromRGB(233, 69, 96),
	CornerRadius = UDim.new(0, 8),
	Padding = 12,
	DropShadowColor = Color3.fromRGB(0, 0, 0),
	DropShadowTransparency = 0.4,
	DropShadowThickness = 2,
	SlideInTime = 0.2,
	FadeTime = 0.15,
	ButtonHoverScale = 1.05,
	ButtonPressScale = 0.95,
	RarityColors = {
		Common = Color3.fromRGB(155, 155, 155),
		Uncommon = Color3.fromRGB(76, 175, 80),
		Rare = Color3.fromRGB(33, 150, 243),
		Epic = Color3.fromRGB(156, 39, 176),
		Legendary = Color3.fromRGB(255, 152, 0),
	},
}

return Config
