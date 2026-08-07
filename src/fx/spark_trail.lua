-- src/fx/spark_trail.lua — a continuous emitter for effects that persist
-- while attached to a living entity (e.g. a glowing boulder or a locked
-- door). Unlike the burst presets it does not auto-spawn on construction:
-- the owning entity calls `emit()` (or `self.sparkTrail.emitter:emit(n)`)
-- once per frame from its update, and draws via the FxManager or an
-- attached component.
--
--   self.sparkTrail = map.fx:add(SparkTrail{x = 0, y = 0, color = {...}})
--   -- each update: self.sparkTrail.opts.position = {x, y}; emit()
local Class = require('lib.hump.class')
local FxBase = require('src.fx.base')

local SparkTrail = Class{__includes = FxBase}

function SparkTrail:config()
	return {
		lifetime = {min = 0.1, max = 0.25},
		speed = {min = 0, max = 20},
		direction = {angle = math.pi / 2, spread = 0.3},
		gravity = {x = 0, y = 0},
		size = {start = 8, ["end"] = 0},
		colors = {start = {1, 0.85, 0.6, 0.9}, ["end"] = {1, 0.6, 0.2, 0}},
		image = 'res/fx/fx_blob_glow.png',
	}
end

-- The trail is continuous; expose how many to emit per tick so callers can
-- stay tuned to the cap without picking a magic number.
function SparkTrail:emitCount()
	return 1
end

return SparkTrail