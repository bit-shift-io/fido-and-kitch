-- Common named constants for Fido and Kitch

local GameConstants = {}

-- Player probe/margin literals (used in sensors/ground_support)
GameConstants.PLAYER_PROBE_MARGIN = 4
GameConstants.PLAYER_PROBE_BOTTOM_OFFSET = 5

-- Mover platform literals (template defaults)
GameConstants.MOVER_PLATFORM_DEFAULT_SPEED = 50
GameConstants.MOVER_PLATFORM_DEFAULT_PAUSE = 0.5

-- Jump pad literals (template defaults)
GameConstants.JUMP_PAD_DEFAULT_COUNT = 16
GameConstants.JUMP_PAD_DEFAULT_SPEED = 120

-- Collision and geometry probes
GameConstants.COLLIDER_WALKABLE_PROBE_X = 2
GameConstants.COLLIDER_WALKABLE_PROBE_Y = 2

return GameConstants
