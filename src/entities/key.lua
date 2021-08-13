local Key = Class{__includes = Entity}

function Key:init(object)
	Entity.init(self)
	self.name = 'key'
	local color = object.properties.color
	local sprite = self:addComponent(Sprite{
		image=string.format('res/img/key_%s.png', color), 
		frames=1, 
		duration=1.0, 
		loop=false
	})
	local collider = self:addComponent(Collider{
		shape_type='circle', 
		shape_arguments={0, 0, 10}, 
		body_type='static',
		postSolve=Key.contact, 
		sprite=sprite, 
		position=Vector(object.x + 16, object.y - 32)
	})
	
end

function Key:contact(other)
	print('Key has made contact with something!')
end

return Key