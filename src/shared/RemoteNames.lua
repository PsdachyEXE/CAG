-- Central registry of all remote event/function names
local RemoteNames = {
	-- Weapons
	WeaponFire = "WeaponFire",
	WeaponHit = "WeaponHit",
	DamageNumber = "DamageNumber",

	-- AI
	AISpawn = "AISpawn",
	AIDied = "AIDied",

	-- Extraction
	ExtractionStart = "ExtractionStart",
	ExtractionProgress = "ExtractionProgress",
	ExtractionComplete = "ExtractionComplete",
	ExtractionCancel = "ExtractionCancel",

	-- Round
	RoundEnd = "RoundEnd",
}

return RemoteNames
