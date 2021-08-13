local Switch = Class{__includes = Entity}

function Switch:init(object)
	Entity.init(self)
	self.name = 'switch'
	local sprite = self:addComponent(Sprite{
		image='res/img/switch.png', 
		scale=Vector(0.3, 0.3), 
		frames=2, 
		duration=1.0, 
		loop=false
	})
	local collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments={0, 0, 30, 30}, 
		body_type='static',
		postSolve=Switch.contact, 
		sprite=sprite, 
		position=Vector(object.x, object.y)
	})
	
end

function Switch:contact(other)
	print('Switch has made contact with something!')
end

return Switch