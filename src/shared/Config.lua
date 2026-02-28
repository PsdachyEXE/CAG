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
	XPPlaceholder = 247,
	StreakPlaceholder = 3,
	LootPlaceholder = { "Rusty Pistol Skin", "Scrap Metal x5", "Mystery Crate" },
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

return Config
