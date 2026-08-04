-- src/fx/dust_burst.lua — a soft brown dust puff (footsteps, landings,
-- objects dropped on the ground). Slow, low-speed squares that puff outward
-- briefly under gravity and settle.
--
--   map.fx:burst(DustBurst, {x = px, y = py, count = 8})
local Class = require('lib.hump.class')
local FxBase = require('src.fx.base')

local DustBurst = Class{__includes = FxBase}

function DustBurst:config()
	return {
		lifetime = {min = 0.25, max = 0.5},
		speed = {min = 8, max = 40},
		direction = {angle = -math.pi / 2, spread = math.pi},
		gravity = {x = 0, y = 160},
		size = {start = 10, ["end"] = 2},
		colors = {start = {0.62, 0.52, 0.42, 0.55}, ["end"] = {0.5, 0.42, 0.36, 0}},
	}
end

function DustBurst:emitCount()
	return 10
end

return DustBurst