local PickupProp = require('src.entities.pickup_prop')

return PickupProp.define{
	type = 'key',
	pickupSound = 'res/snd/entity_key_collect.wav',
	itemName = function(object) return string.format('key_%s', object.properties.color) end,
	sprite = function(object, shape_arguments)
		return {
			image = string.format('res/img/key_%s.png', object.properties.color),
			frames = 1,
			duration = 1.0,
			loop = false,
			shape_arguments = shape_arguments,
		}
	end,
}
