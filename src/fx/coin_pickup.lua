-- src/fx/coin_pickup.lua — the coin-collect sparkle burst.
-- A one-shot fountain of yellow-gold squares that flies up and out, then
-- shrinks and fades under gravity. Triggered by PickupProp when a pickup
-- entity declares `pickupFx` (see src/entities/coin.lua).
--
--   map.fx:burst(CoinPickup, {x = coinX, y = coinY})
local Class = require('lib.hump.class')
local FxBase = require('src.fx.base')

local CoinPickup = Class{__includes = FxBase}

function CoinPickup:config()
	return {
		lifetime = {min = 0.3, max = 0.6},
		speed = {min = 40, max = 140},
		direction = {angle = -math.pi / 2, spread = math.pi},
		gravity = {x = 0, y = 220},
		size = {start = 14, ["end"] = 0},
		colors = {start = {1, 0.9, 0.2, 1}, ["end"] = {1, 0.5, 0, 0}},
		image = 'res/fx/fx_star_glow.png',
	}
end

function CoinPickup:emitCount()
	return 12
end

return CoinPickup