-- src/fx/tile_shatter.lua — a burst of stone debris when a destructible
-- tile breaks (direct beam hit or chain-cascade force-destroy).
-- Small gray squares kick outward in every direction and fall under
-- gravity, mirroring rubble flying off a broken tile rather than the
-- upward/conical bursts (coin pickup, jump pad) used elsewhere in src/fx/.
--
--   map.fx:burst(TileShatter, {x = tileX, y = tileY})
local Class = require('lib.hump.class')
local FxBase = require('src.fx.base')

local TileShatter = Class{__includes = FxBase}

function TileShatter:config()
	return {
		lifetime = {min = 0.2, max = 0.4},
		speed = {min = 60, max = 220},
		direction = {angle = 0, spread = math.pi * 2}, -- omnidirectional
		gravity = {x = 0, y = 400},
		size = {start = 8, ["end"] = 0},
		colors = {start = {0.55, 0.53, 0.5, 1}, ["end"] = {0.3, 0.28, 0.26, 0}},
		image = 'res/img/fx/fx_square_outline.png',
	}
end

function TileShatter:emitCount()
	return 14
end

return TileShatter
