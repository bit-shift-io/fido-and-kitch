local Key = Class{__includes = Entity}

function Key:init(object)
	Entity.init(self)
	self.type = 'key'
	local color = object.properties.color
	local position = Vector(object.x - object.width * 0.5, object.y - object.height * 0.5)
	local shape_arguments = {0, 0, object.width, object.height}
	self.sprite = self:addComponent(Sprite{
		image=string.format('res/img/key_%s.png', color), 
		frames=1, 
		duration=1.0, 
		loop=false,
		shape_arguments=shape_arguments,
	})

	self.collider = self:addComponent(Collider{
		shape_type='circle',
		shape_arguments={0, 0, 10},
		body_type='static',
		postSolve=Func(Key.contact, self),
		sprite=self.sprite,
		position=position,
		sensor=true,
		entity=self
	})
	
	self:addComponent(Pickup{
		itemName=string.format('key_%s', color),
		collider=self.collider,
		entity=self
	})
end

return Key