--[[
	LootTableData — static item pool for all loot sources.
	No logic, data only. Referenced by LootTableServer and client UI.

	Fields:
	  id, name, type, rarity, value          — core
	  icon, isWeapon, category               — display / sorting
	  groundModel, handModel                 — world model paths (nil = generic crate)

	Weapon-only fields:
	  damage, fireMode, fireRate, magSize, reloadTime,
	  spread, adsSpread, recoilKick, burstCount,
	  pellets, pelletSpread, hipfireSpread
]]

local LootTableData = {
	-- ── Materials (Common / Uncommon / Rare) ─────────────
	{ id = "mat_scrap",    name = "Scrap Metal",     type = "material", rarity = "Common",   value = 10,
	  icon = "\u{1F9F1}", isWeapon = false, category = "material", groundModel = nil, handModel = nil },
	{ id = "mat_wire",     name = "Copper Wire",     type = "material", rarity = "Common",   value = 10,
	  icon = "\u{1F50C}", isWeapon = false, category = "material", groundModel = nil, handModel = nil },
	{ id = "mat_cloth",    name = "Torn Cloth",      type = "material", rarity = "Common",   value = 8,
	  icon = "\u{1F9F5}", isWeapon = false, category = "material", groundModel = nil, handModel = nil },
	{ id = "mat_tape",     name = "Duct Tape",       type = "material", rarity = "Common",   value = 12,
	  icon = "\u{1F4E6}", isWeapon = false, category = "material", groundModel = nil, handModel = nil },
	{ id = "mat_bolt",     name = "Rusted Bolts",    type = "material", rarity = "Common",   value = 9,
	  icon = "\u{1F529}", isWeapon = false, category = "material", groundModel = nil, handModel = nil },
	{ id = "mat_circuit",  name = "Circuit Board",   type = "material", rarity = "Uncommon", value = 25,
	  icon = "\u{1F4DF}", isWeapon = false, category = "material", groundModel = nil, handModel = nil },
	{ id = "mat_polymer",  name = "Polymer Sheet",   type = "material", rarity = "Uncommon", value = 22,
	  icon = "\u{1F4C4}", isWeapon = false, category = "material", groundModel = nil, handModel = nil },
	{ id = "mat_alloy",    name = "Titanium Alloy",  type = "material", rarity = "Rare",     value = 50,
	  icon = "\u{2699}",  isWeapon = false, category = "material", groundModel = nil, handModel = nil },

	-- ── Weapons ─────────────────────────────────────────

	-- AR
	{ id = "wpn_ak47", name = "AK-47", type = "weapon_variant", rarity = "Uncommon", value = 40,
	  icon = "\u{1F52B}", isWeapon = true, category = "AR",
	  groundModel = "Weapons/AR/AK-47/AK-47", handModel = "Weapons/AR/AK-47/AK-47",
	  damage = 25, fireMode = {"auto", "semi"}, fireRate = 600,
	  magSize = 30, reloadTime = 2.5, spread = 0.03, adsSpread = 0.008,
	  recoilKick = 0.15, burstCount = nil, pellets = nil,
	  pelletSpread = nil, hipfireSpread = 0.03 },

	{ id = "wpn_famas", name = "FAMAS", type = "weapon_variant", rarity = "Rare", value = 55,
	  icon = "\u{1F52B}", isWeapon = true, category = "AR",
	  groundModel = "Weapons/AR/FAMAS/FAMAS", handModel = "Weapons/AR/FAMAS/FAMAS",
	  damage = 25, fireMode = {"auto", "burst", "semi"}, fireRate = 900,
	  magSize = 25, reloadTime = 2.3, spread = 0.025, adsSpread = 0.007,
	  recoilKick = 0.1, burstCount = 3, pellets = nil,
	  pelletSpread = nil, hipfireSpread = 0.025 },

	{ id = "wpn_combat_rifle", name = "Combat Rifle", type = "weapon_variant", rarity = "Rare", value = 60,
	  icon = "\u{1F52B}", isWeapon = true, category = "AR",
	  groundModel = "Weapons/AR/CombatRifle/CombatRifle", handModel = "Weapons/AR/CombatRifle/CombatRifle",
	  damage = 28, fireMode = {"auto", "semi"}, fireRate = 550,
	  magSize = 30, reloadTime = 2.6, spread = 0.028, adsSpread = 0.007,
	  recoilKick = 0.14, burstCount = nil, pellets = nil,
	  pelletSpread = nil, hipfireSpread = 0.028 },

	{ id = "wpn_golden_auto", name = "Golden Auto", type = "weapon_variant", rarity = "Legendary", value = 200,
	  icon = "\u{1F52B}", isWeapon = true, category = "AR",
	  groundModel = "Weapons/AR/GoldenAuto/GoldenAuto", handModel = "Weapons/AR/GoldenAuto/GoldenAuto",
	  damage = 30, fireMode = {"auto", "semi"}, fireRate = 650,
	  magSize = 35, reloadTime = 2.4, spread = 0.022, adsSpread = 0.005,
	  recoilKick = 0.12, burstCount = nil, pellets = nil,
	  pelletSpread = nil, hipfireSpread = 0.022 },

	-- PISTOL
	{ id = "wpn_rusty_pistol", name = "Rusty Pistol", type = "weapon_variant", rarity = "Common", value = 15,
	  icon = "\u{1F52B}", isWeapon = true, category = "PISTOL",
	  groundModel = "Weapons/PISTOL/RustyPistol/RustyPistol", handModel = "Weapons/PISTOL/RustyPistol/RustyPistol",
	  damage = 8, fireMode = {"semi"}, fireRate = 350,
	  magSize = 12, reloadTime = 1.6, spread = 0.03, adsSpread = 0.008,
	  recoilKick = 0.1, burstCount = nil, pellets = nil,
	  pelletSpread = nil, hipfireSpread = 0.03 },

	{ id = "wpn_glock", name = "Glock", type = "weapon_variant", rarity = "Common", value = 18,
	  icon = "\u{1F52B}", isWeapon = true, category = "PISTOL",
	  groundModel = "Weapons/PISTOL/Glock/Glock", handModel = "Weapons/PISTOL/Glock/Glock",
	  damage = 10, fireMode = {"semi"}, fireRate = 400,
	  magSize = 15, reloadTime = 1.8, spread = 0.025, adsSpread = 0.006,
	  recoilKick = 0.1, burstCount = nil, pellets = nil,
	  pelletSpread = nil, hipfireSpread = 0.025 },

	{ id = "wpn_plasma_pistol", name = "Plasma Pistol", type = "weapon_variant", rarity = "Epic", value = 100,
	  icon = "\u{1F52B}", isWeapon = true, category = "PISTOL",
	  groundModel = "Weapons/PISTOL/PlasmaPistol/PlasmaPistol", handModel = "Weapons/PISTOL/PlasmaPistol/PlasmaPistol",
	  damage = 18, fireMode = {"semi"}, fireRate = 300,
	  magSize = 10, reloadTime = 2.0, spread = 0.02, adsSpread = 0.004,
	  recoilKick = 0.12, burstCount = nil, pellets = nil,
	  pelletSpread = nil, hipfireSpread = 0.02 },

	-- SMG
	{ id = "wpn_tactical_smg", name = "Tactical SMG", type = "weapon_variant", rarity = "Uncommon", value = 30,
	  icon = "\u{1F52B}", isWeapon = true, category = "SMG",
	  groundModel = "Weapons/SMG/TacticalSMG/TacticalSMG", handModel = "Weapons/SMG/TacticalSMG/TacticalSMG",
	  damage = 10, fireMode = {"auto", "semi"}, fireRate = 700,
	  magSize = 25, reloadTime = 2.0, spread = 0.035, adsSpread = 0.01,
	  recoilKick = 0.08, burstCount = nil, pellets = nil,
	  pelletSpread = nil, hipfireSpread = 0.035 },

	{ id = "wpn_ump", name = "UMP", type = "weapon_variant", rarity = "Uncommon", value = 32,
	  icon = "\u{1F52B}", isWeapon = true, category = "SMG",
	  groundModel = "Weapons/SMG/UMP/UMP", handModel = "Weapons/SMG/UMP/UMP",
	  damage = 10, fireMode = {"auto", "semi"}, fireRate = 700,
	  magSize = 25, reloadTime = 2.0, spread = 0.035, adsSpread = 0.01,
	  recoilKick = 0.08, burstCount = nil, pellets = nil,
	  pelletSpread = nil, hipfireSpread = 0.035 },

	-- SNIPER
	{ id = "wpn_awm", name = "AWM", type = "weapon_variant", rarity = "Epic", value = 120,
	  icon = "\u{1F52B}", isWeapon = true, category = "SNIPER",
	  groundModel = "Weapons/SNIPER/AWM/AWM", handModel = "Weapons/SNIPER/AWM/AWM",
	  damage = 75, fireMode = {"semi"}, fireRate = 50,
	  magSize = 5, reloadTime = 3.5, spread = 0.18, adsSpread = 0,
	  recoilKick = 0.4, burstCount = nil, pellets = nil,
	  pelletSpread = nil, hipfireSpread = 0.18 },

	-- SHOTGUN
	{ id = "wpn_spas12", name = "SPAS-12", type = "weapon_variant", rarity = "Rare", value = 65,
	  icon = "\u{1F52B}", isWeapon = true, category = "SHOTGUN",
	  groundModel = "Weapons/SHOTGUN/SPAS12/SPAS12", handModel = "Weapons/SHOTGUN/SPAS12/SPAS12",
	  damage = 8, fireMode = {"semi"}, fireRate = 80,
	  magSize = 8, reloadTime = 3.0, spread = 10, adsSpread = 5,
	  recoilKick = 0.35, burstCount = nil, pellets = 8,
	  pelletSpread = 10, hipfireSpread = 10 },

	-- MG
	{ id = "wpn_m249", name = "M249", type = "weapon_variant", rarity = "Epic", value = 110,
	  icon = "\u{1F52B}", isWeapon = true, category = "MG",
	  groundModel = "Weapons/MG/M249/M249", handModel = "Weapons/MG/M249/M249",
	  damage = 17, fireMode = {"auto"}, fireRate = 750,
	  magSize = 100, reloadTime = 4.5, spread = 0.05, adsSpread = 0.015,
	  recoilKick = 0.12, burstCount = nil, pellets = nil,
	  pelletSpread = nil, hipfireSpread = 0.05 },

	-- ── Modifiers (Uncommon / Rare / Epic) ──────────────
	{ id = "mod_quickdraw",    name = "Quickdraw Grip",     type = "modifier", rarity = "Uncommon", value = 20,
	  icon = "\u{1F3AF}", isWeapon = false, category = "modifier", groundModel = nil, handModel = nil },
	{ id = "mod_extended_mag", name = "Extended Magazine",   type = "modifier", rarity = "Uncommon", value = 20,
	  icon = "\u{1F4E5}", isWeapon = false, category = "modifier", groundModel = nil, handModel = nil },
	{ id = "mod_stabilizer",   name = "Barrel Stabilizer",  type = "modifier", rarity = "Rare",     value = 45,
	  icon = "\u{1F527}", isWeapon = false, category = "modifier", groundModel = nil, handModel = nil },
	{ id = "mod_holo_sight",   name = "Holo Sight",         type = "modifier", rarity = "Rare",     value = 40,
	  icon = "\u{1F50D}", isWeapon = false, category = "modifier", groundModel = nil, handModel = nil },
	{ id = "mod_overclock",    name = "Overclock Chip",     type = "modifier", rarity = "Epic",     value = 85,
	  icon = "\u{26A1}",  isWeapon = false, category = "modifier", groundModel = nil, handModel = nil },

	-- ── Multipliers (Uncommon / Rare / Epic / Legendary) ─
	{ id = "mul_xp_small",  name = "XP Chip (+25%)",          type = "multiplier", rarity = "Uncommon",  value = 25,
	  icon = "\u{2B50}", isWeapon = false, category = "multiplier", groundModel = nil, handModel = nil },
	{ id = "mul_xp_large",  name = "XP Module (+50%)",        type = "multiplier", rarity = "Rare",      value = 50,
	  icon = "\u{1F31F}", isWeapon = false, category = "multiplier", groundModel = nil, handModel = nil },
	{ id = "mul_xp_mega",   name = "XP Overcharger (+100%)",  type = "multiplier", rarity = "Epic",      value = 100,
	  icon = "\u{1F4AB}", isWeapon = false, category = "multiplier", groundModel = nil, handModel = nil },
	{ id = "mul_loot_luck", name = "Lucky Charm",             type = "multiplier", rarity = "Legendary", value = 150,
	  icon = "\u{1F340}", isWeapon = false, category = "multiplier", groundModel = nil, handModel = nil },
}

return LootTableData
