local Coin = Class{__includes = Entity}

function Coin:init(object)
	Entity.init(self)
	self.name = 'coin'
	local sprite = self:addComponent(Sprite{
		image='res/img/coins.png', 
		frames=8, 
		duration=1.0, 
		loop=true,
		playing=true
	})
	
	local collider = self:addComponent(Collider{
		shape_type='circle', 
		shape_arguments={0, 0, 10}, 
		body_type='static',
		sprite=sprite, 
		position=Vector(object.x + 16, object.y - 16),
		sensor=true,
		entity=self
	})

	self:addComponent(Pickup{
		itemName=self.name,
		collider=collider,
		entity=self
	})
end

return Coin