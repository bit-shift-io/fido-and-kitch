local Coin = Class{__includes = Entity}

function Coin:init(object)
	Entity.init(self)
	local sprite = self:addComponent(Sprite{
		image='res/img/coins.png', 
		frames=8, 
		duration=1.0, 
		loop=true
	})
	
	local collider = self:addComponent(Collider{
		shape_type='circle', 
		shape_arguments={0, 0, 10}, 
		body_type='static',
		postSolve=Coin.contact, 
		sprite=sprite, 
		position=Vector(object.x + 16, object.y - 32)})
	
end

function Coin:contact(other)
	print('coin has made contact with something!')
end

return Coin