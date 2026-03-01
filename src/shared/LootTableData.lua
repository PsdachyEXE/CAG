--[[
	LootTableData — static item pool for all loot sources.
	No logic, data only. Referenced by LootTableServer and client UI.
	Categories: materials, weapon_variants, modifiers, multipliers
]]

local LootTableData = {
	-- Materials (Common / Uncommon / Rare)
	{ id = "mat_scrap",    name = "Scrap Metal",     type = "material", rarity = "Common",   value = 10 },
	{ id = "mat_wire",     name = "Copper Wire",     type = "material", rarity = "Common",   value = 10 },
	{ id = "mat_cloth",    name = "Torn Cloth",      type = "material", rarity = "Common",   value = 8  },
	{ id = "mat_tape",     name = "Duct Tape",       type = "material", rarity = "Common",   value = 12 },
	{ id = "mat_bolt",     name = "Rusted Bolts",    type = "material", rarity = "Common",   value = 9  },
	{ id = "mat_circuit",  name = "Circuit Board",   type = "material", rarity = "Uncommon", value = 25 },
	{ id = "mat_polymer",  name = "Polymer Sheet",   type = "material", rarity = "Uncommon", value = 22 },
	{ id = "mat_alloy",    name = "Titanium Alloy",  type = "material", rarity = "Rare",     value = 50 },

	-- Weapon Variants (all rarities)
	{ id = "wpn_rusty_pistol",  name = "Rusty Pistol",   type = "weapon_variant", rarity = "Common",    value = 15  },
	{ id = "wpn_tactical_smg",  name = "Tactical SMG",   type = "weapon_variant", rarity = "Uncommon",  value = 30  },
	{ id = "wpn_combat_rifle",  name = "Combat Rifle",   type = "weapon_variant", rarity = "Rare",      value = 60  },
	{ id = "wpn_plasma_pistol", name = "Plasma Pistol",  type = "weapon_variant", rarity = "Epic",      value = 100 },
	{ id = "wpn_golden_auto",   name = "Golden Auto",    type = "weapon_variant", rarity = "Legendary", value = 200 },

	-- Modifiers (Uncommon / Rare / Epic)
	{ id = "mod_quickdraw",    name = "Quickdraw Grip",    type = "modifier", rarity = "Uncommon", value = 20 },
	{ id = "mod_extended_mag", name = "Extended Magazine",  type = "modifier", rarity = "Uncommon", value = 20 },
	{ id = "mod_stabilizer",   name = "Barrel Stabilizer",  type = "modifier", rarity = "Rare",     value = 45 },
	{ id = "mod_holo_sight",   name = "Holo Sight",        type = "modifier", rarity = "Rare",     value = 40 },
	{ id = "mod_overclock",    name = "Overclock Chip",    type = "modifier", rarity = "Epic",     value = 85 },

	-- Multipliers (Uncommon / Rare / Epic / Legendary)
	{ id = "mul_xp_small",  name = "XP Chip (+25%)",       type = "multiplier", rarity = "Uncommon",  value = 25  },
	{ id = "mul_xp_large",  name = "XP Module (+50%)",     type = "multiplier", rarity = "Rare",      value = 50  },
	{ id = "mul_xp_mega",   name = "XP Overcharger (+100%)", type = "multiplier", rarity = "Epic",    value = 100 },
	{ id = "mul_loot_luck", name = "Lucky Charm",          type = "multiplier", rarity = "Legendary", value = 150 },
}

return LootTableData
