local Key = Class{__includes = Entity}

function Key:init(object)
	Entity.init(self)
	self.name = 'key'
	local color = object.properties.color
	local sprite = self:addComponent(Sprite{
		image=string.format('res/img/key_%s.png', color), 
		frames=1, 
		duration=1.0, 
		loop=false,
		scale=Vector(0.8,0.8),
		offset=Vector(12,12)
	})

	local collider = self:addComponent(Collider{
		shape_type='circle', 
		shape_arguments={0, 0, 10}, 
		body_type='static',
		postSolve=Func(Key.contact, self), 
		sprite=sprite, 
		position=Vector(object.x + 16, object.y - 16),
		sensor=true,
		entity=self
	})
	
	self:addComponent(Pickup{
		itemName=string.format('key_%s', color),
		collider=collider,
		entity=self
	})
end

return Key