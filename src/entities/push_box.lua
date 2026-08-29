local PushableProp = require('src.entities.pushable_prop')
local SpriteProps = require('src.entities.sprite_props')

return PushableProp.define{
	type = 'push_box',
	sprite = function(object, shape_arguments)
		local art = SpriteProps.fromObject(object)
		art.shape_arguments = shape_arguments
		return art
	end,
}