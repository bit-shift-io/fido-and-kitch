local Coin = Class{__includes = Entity}

function Coin:init(object)
	Entity.init(self)
	self.type = 'coin'
	self.name = object.name
	local position = Vector(object.x + object.width * 0.5, object.y - object.height * 0.5)
	local shape_arguments = {0, 0, object.width, object.height}
	self.sprite = self:addComponent(Sprite{
		image='res/img/coins.png',
		frames=8,
		duration=1.0,
		loop=true,
		playing=true,
		shape_arguments=shape_arguments,
		scale=Vector(0.8,0.8)
	})
	
	self.collider = self:addComponent(Collider{
		shape_type='circle',
		shape_arguments={0, 0, 10},
		body_type='static',
		sprite=self.sprite,
		position=position,
		sensor=true,
		entity=self
	})

	self:addComponent(Pickup{
		itemName=self.name,
		collider=self.collider,
		entity=self
	})
end

return Coin