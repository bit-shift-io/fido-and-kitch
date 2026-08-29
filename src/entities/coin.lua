local PickupProp = require('src.entities.pickup_prop')
local SpriteProps = require('src.entities.sprite_props')
local CoinPickup = require('src.fx.coin_pickup')

return PickupProp.define{
	type = 'coin',
	pickupFx = CoinPickup,
	pickupSound = 'res/snd/entity_coin_collect.wav',
	itemName = function(object) return 'coin' end,
	sprite = function(object, shape_arguments)
		local art = SpriteProps.fromObject(object)
		art.shape_arguments = shape_arguments
		return art
	end,
}
