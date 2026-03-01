--[[
	ProgressionData — static unlock milestones by level.
	No logic, data only. Referenced by ProgressionServer and client UI.
	Types: feature, weapon, cosmetic, currency
]]

local ProgressionData = {
	{ level = 2,  type = "feature",  id = "second_weapon_slot", displayName = "Second Weapon Slot" },
	{ level = 3,  type = "currency", id = "currency_500",       displayName = "500 Credits",        amount = 500  },
	{ level = 5,  type = "weapon",   id = "wpn_variant_01",     displayName = "Tactical Variant" },
	{ level = 7,  type = "cosmetic", id = "cos_camo_01",        displayName = "Urban Camo Skin" },
	{ level = 10, type = "feature",  id = "squad_size_4",       displayName = "Squad Size 4" },
	{ level = 12, type = "currency", id = "currency_750",       displayName = "750 Credits",        amount = 750  },
	{ level = 15, type = "weapon",   id = "wpn_variant_02",     displayName = "Stealth Variant" },
	{ level = 17, type = "cosmetic", id = "cos_neon_01",        displayName = "Neon Glow Trail" },
	{ level = 20, type = "currency", id = "currency_1000",      displayName = "1000 Credits",       amount = 1000 },
	{ level = 22, type = "weapon",   id = "wpn_variant_03",     displayName = "Heavy Variant" },
	{ level = 25, type = "currency", id = "currency_1500",      displayName = "1500 Credits",       amount = 1500 },
	{ level = 27, type = "cosmetic", id = "cos_flame_01",       displayName = "Flame Effect" },
	{ level = 30, type = "weapon",   id = "wpn_variant_04",     displayName = "Plasma Variant" },
	{ level = 32, type = "currency", id = "currency_2000",      displayName = "2000 Credits",       amount = 2000 },
	{ level = 35, type = "cosmetic", id = "cos_holo_01",        displayName = "Holographic Skin" },
	{ level = 37, type = "currency", id = "currency_2500",      displayName = "2500 Credits",       amount = 2500 },
	{ level = 40, type = "weapon",   id = "wpn_variant_05",     displayName = "Elite Variant" },
	{ level = 43, type = "currency", id = "currency_3000",      displayName = "3000 Credits",       amount = 3000 },
	{ level = 45, type = "cosmetic", id = "cos_legendary_01",   displayName = "Legendary Aura" },
	{ level = 50, type = "weapon",   id = "wpn_variant_gold",   displayName = "Golden Arsenal" },
}

return ProgressionData
