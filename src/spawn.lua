local Spawn = Class{__includes = Entity}

function Spawn:init(object)
	Entity.init(self)
	self.name = 'spawn'
	local sprite = self:addComponent(Sprite{
		image='res/img/door.png',
		scale=Vector(0.8, 0.8), 
		frames=5, 
		duration=1.0, 
		loop=false
	})
	local collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments={0, 0, 50, 50}, 
		body_type='static',
		postSolve=Spawn.contact, 
		sprite=sprite, 
		position=Vector(object.x, object.y)
	})
	
end

function Spawn:contact(other)
	print('Spawn has made contact with something!')
end

return Spawn