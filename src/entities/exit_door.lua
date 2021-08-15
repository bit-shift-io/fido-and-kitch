local ExitDoor = Class{__includes = Entity}

function ExitDoor:init(object)
	Entity.init(self)
	self.name = 'exit door'
	local position = Vector(object.x, object.y)
	local sprite = self:addComponent(Sprite{
		image='res/img/door.png',
		scale=Vector(0.8, 0.8), 
		frames=5, 
		duration=1.0, 
		loop=false,
		position=position
	})
	local collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments={0, 0, 50, 50}, 
		body_type='static',
		enter=Func(ExitDoor.contact, self),
		sensor=true,
		position=position
	})
	
end

function ExitDoor:contact(other)
end

return ExitDoor