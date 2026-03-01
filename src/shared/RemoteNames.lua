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
	PlayerEliminated = "PlayerEliminated",

	-- Extraction
	ExtractionStart = "ExtractionStart",
	ExtractionProgress = "ExtractionProgress",
	ExtractionComplete = "ExtractionComplete",
	ExtractionCancel = "ExtractionCancel",

	-- Round
	RoundEnd = "RoundEnd",
	PlayAgain = "PlayAgain",
	RoundStateChanged = "RoundStateChanged",
	MatchTimeUpdate = "MatchTimeUpdate",
	PlayerReady = "PlayerReady",

	-- Inventory
	VolatileItemsLost = "VolatileItemsLost",
	VolatileItemsExtracted = "VolatileItemsExtracted",
	InventoryUpdate = "InventoryUpdate",

	-- Loot
	LootReceived = "LootReceived",
	ContainerLooted = "ContainerLooted",
	ContainerInteract = "ContainerInteract",

	-- Airdrop
	AirdropIncoming = "AirdropIncoming",
	AirdropLanded = "AirdropLanded",

	-- Squad
	CreateSquad = "CreateSquad",
	InviteToSquad = "InviteToSquad",
	AcceptSquadInvite = "AcceptSquadInvite",
	DeclineSquadInvite = "DeclineSquadInvite",
	LeaveSquad = "LeaveSquad",
	SquadUpdate = "SquadUpdate",
	SquadMemberDied = "SquadMemberDied",
	SquadHealthUpdate = "SquadHealthUpdate",
	SquadInviteReceived = "SquadInviteReceived",

	-- Spectator
	SpectatorTarget = "SpectatorTarget",

	-- Kill feed
	KillFeedEntry = "KillFeedEntry",

	-- Leaderboard
	LeaderboardUpdate = "LeaderboardUpdate",

	-- Progression
	LevelUp = "LevelUp",
	XPGained = "XPGained",

	-- Notification
	ShowNotification = "ShowNotification",
}

return RemoteNames
