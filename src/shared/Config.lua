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

-- Ground items / Pickup
Config.PICKUP_RANGE = 6
Config.CROSSHAIR_RAY_LENGTH = 10

-- Equip
Config.UNEQUIP_KEY = "G"
Config.WEAPON_EQUIP_OFFSET = { 1.5, -0.5, -1 }
Config.WEAPON_EQUIP_ROTATION = { 0, 90, 0 }

-- Combat / Viewmodel
Config.WEAPON_SWAP_DELAY = 0.6
Config.ADS_TRANSITION_TIME = 0.5
Config.ADS_FOV_REDUCTION = 15
Config.DEFAULT_FOV = 70
Config.RECOIL_RECOVERY_TIME = 0.12
Config.BURST_DELAY = 0.1
Config.CAMERA_KICK_RECOVERY = 0.15
Config.VIEWMODEL_OFFSET = { 0.5, -0.5, -1.5 }
Config.VIEWMODEL_ADS_OFFSET = { 0, -0.15, -1.2 }

return Config
