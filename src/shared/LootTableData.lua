--[[
	LootTableData — static item pool for all loot sources.
	No logic, data only. Referenced by LootTableServer and client UI.
	Categories: materials, weapon_variants, modifiers, multipliers

	Fields:
	  id, name, type, rarity, value          — core
	  icon, isWeapon, category               — display / sorting
	  groundModel, handModel                 — world model paths (nil = generic crate)
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

	-- ── Weapon Variants (all rarities) ──────────────────
	{ id = "wpn_rusty_pistol",  name = "Rusty Pistol",   type = "weapon_variant", rarity = "Common",    value = 15,
	  icon = "\u{1F52B}", isWeapon = true,  category = "PISTOL", groundModel = "Weapons/PISTOL/RustyPistol", handModel = "Weapons/PISTOL/RustyPistol" },
	{ id = "wpn_tactical_smg",  name = "Tactical SMG",   type = "weapon_variant", rarity = "Uncommon",  value = 30,
	  icon = "\u{1F52B}", isWeapon = true,  category = "SMG",    groundModel = "Weapons/SMG/TacticalSMG",   handModel = "Weapons/SMG/TacticalSMG" },
	{ id = "wpn_ak47",          name = "AK-47",          type = "weapon_variant", rarity = "Uncommon",  value = 40,
	  icon = "\u{1F52B}", isWeapon = true,  category = "AR",     groundModel = "Weapons/AR/AK47",           handModel = "Weapons/AR/AK47" },
	{ id = "wpn_combat_rifle",  name = "Combat Rifle",   type = "weapon_variant", rarity = "Rare",      value = 60,
	  icon = "\u{1F52B}", isWeapon = true,  category = "AR",     groundModel = "Weapons/AR/CombatRifle",    handModel = "Weapons/AR/CombatRifle" },
	{ id = "wpn_plasma_pistol", name = "Plasma Pistol",  type = "weapon_variant", rarity = "Epic",      value = 100,
	  icon = "\u{1F52B}", isWeapon = true,  category = "PISTOL", groundModel = "Weapons/PISTOL/PlasmaPistol", handModel = "Weapons/PISTOL/PlasmaPistol" },
	{ id = "wpn_golden_auto",   name = "Golden Auto",    type = "weapon_variant", rarity = "Legendary", value = 200,
	  icon = "\u{1F52B}", isWeapon = true,  category = "AR",     groundModel = "Weapons/AR/GoldenAuto",     handModel = "Weapons/AR/GoldenAuto" },

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
