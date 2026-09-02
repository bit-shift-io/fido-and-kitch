-- src/fx/jump_pad_streak.lua — burst of streaking particles when a jump pad launches
-- Emits elongated particles flying outward along the launch direction
--   map.fx:burst(JumpPadStreak, {x = px, y = py, angle = rad, count = 16})
local Class = require("lib.hump.class")
local FxBase = require("src.fx.base")

local JumpPadStreak = Class({ __includes = FxBase })

function JumpPadStreak:config()
	return {
		lifetime = { min = 0.2, max = 0.45 },
		speed = { min = 180, max = 320 },
		direction = { angle = self.opts and self.opts.angle or -math.pi / 2, spread = 0.35 },
		gravity = { x = 0, y = 80 },
		size = { start = 28, ["end"] = 4 },
		colors = { start = { 1, 0.95, 0.7, 0.95 }, ["end"] = { 1, 0.6, 0.2, 0 } },
		image = "res/img/fx/fx_blob_glow.png",
		rotation = { angle = self.opts and self.opts.angle or -math.pi / 2, spread = 0.1 },
		spin = { min = -6, max = 6 },
		fadeIn = 0.1,
		area = { w = 6, h = 6 },
	}
end

function JumpPadStreak:emitCount()
	return self.opts and self.opts.count or 14
end

return JumpPadStreak
