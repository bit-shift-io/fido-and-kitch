local PickupProp = require('src.entities.pickup_prop')
local KEY_COLORS = {
	red    = {1, 0.2, 0.2, 1},
	blue   = {0.2, 0.4, 1, 1},
	yellow = {1, 0.9, 0.2, 1},
	green  = {0.2, 0.8, 0.3, 1},
	purple = {0.7, 0.3, 1, 1},
}

return PickupProp.define{
	type = 'key',
	pickupSound = 'res/snd/entity_key_collect.wav',
	itemName = function(object) return string.format('key_%s', object.properties.color) end,
	sprite = function(object, shape_arguments)
		return {
			image = 'res/img/entity_key.png',
			frames = 1,
			duration = 1.0,
			loop = false,
			shape_arguments = shape_arguments,
		}
	end,
	components = function(object)
		local colorName = object.properties.color or 'yellow'
		return {
			Tint = { color = KEY_COLORS[colorName] or KEY_COLORS.yellow }
		}
	end,
}
