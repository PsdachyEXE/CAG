local Config = {}

Config.INTERACT_RANGE = 6
Config.INTERACT_COOLDOWN = 0.5
Config.CONTAINER_LOOT_DELAY = 0.5

-- Inventory
Config.MAX_INVENTORY_SLOTS = 16
Config.HOTBAR_SLOTS = 6
Config.TOOLTIP_HOVER_DELAY = 0.5

-- Container roll counts by model name
Config.CONTAINER_ROLLS = {
	ContainerLarge = { min = 5, max = 8 },
	ContainerMedium = { min = 3, max = 5 },
	ContainerSmall = { min = 1, max = 3 },
}

return Config
