-- Central registry of all remote event/function names
local RemoteNames = {
	-- Weapons
	WeaponFire = "WeaponFire",
	WeaponHit = "WeaponHit",
	WeaponHitConfirm = "WeaponHitConfirm",
	DamageNumber = "DamageNumber",

	-- AI
	AISpawn = "AISpawn",
	AIDied = "AIDied",
	AIStagger = "AIStagger",

	-- Player feedback
	PlayerDamaged = "PlayerDamaged",

	-- Extraction
	ExtractionStart = "ExtractionStart",
	ExtractionProgress = "ExtractionProgress",
	ExtractionComplete = "ExtractionComplete",
	ExtractionCancel = "ExtractionCancel",

	-- Round
	RoundEnd = "RoundEnd",
	PlayAgain = "PlayAgain",
}

return RemoteNames
