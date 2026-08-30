local PickupProp = require('src.entities.pickup_prop')
local SpriteProps = require('src.entities.sprite_props')
local KeyColors = require('src.entities.key_colors')

return PickupProp.define{
	type = 'key',
	pickupSound = 'res/snd/entity_key_collect.wav',
	itemName = function(object) return string.format('key_%s', object.properties.color) end,
	sprite = function(object, shape_arguments)
		local art = SpriteProps.fromObject(object)
		art.shape_arguments = shape_arguments
		return art
	end,
	components = function(object)
		local colorName = object.properties.color or 'yellow'
		return {
			Tint = { color = KeyColors.color(colorName) or KeyColors.colors.yellow }
		}
	end,
}
