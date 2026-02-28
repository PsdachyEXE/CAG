local Config = {}

-- Sliding
Config.Slide = {
	Duration = 0.8,
	SpeedMultiplier = 1.8,
	Cooldown = 1.2,
	CameraTiltAngle = 8,
	FrictionDecel = 0.92,
	MinSpeed = 4,
	KeyCode = Enum.KeyCode.LeftControl,
}

-- Weapons
Config.Weapon = {
	MaxRange = 300,
	Damage = 25,
	FireRate = 0.15,
	HeadshotMultiplier = 2,
	HitHighlightColor = Color3.fromRGB(255, 80, 80),
	HitHighlightDuration = 0.15,
	DamageNumberLifetime = 0.8,
	DamageNumberRiseSpeed = 40,
	SpreadAngle = 1.5,
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
	RespawnTime = 5,
}

-- Extraction
Config.Extraction = {
	Duration = 5,
	ZoneSize = Vector3.new(20, 10, 20),
	ZoneColor = Color3.fromRGB(0, 200, 100),
	ZoneTransparency = 0.7,
}

-- Round
Config.Round = {
	EndScreenDuration = 8,
	XPPlaceholder = 100,
}

return Config
