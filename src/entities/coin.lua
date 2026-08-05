local PickupProp = require('src.entities.pickup_prop')
local CoinPickup = require('src.fx.coin_pickup')

return PickupProp.define{
	type = 'coin',
	pickupFx = CoinPickup,
	pickupSound = 'res/snd/entity_coin_collect.wav',
	itemName = function(object) return 'coin' end,
	sprite = function(object, shape_arguments)
		return {
			image = 'res/img/coins.png',
			frames = 8,
			duration = 1.0,
			loop = true,
			playing = true,
			shape_arguments = shape_arguments,
			scale = Vector(0.8, 0.8),
		}
	end,
}
