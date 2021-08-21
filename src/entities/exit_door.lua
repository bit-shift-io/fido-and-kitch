local ExitDoor = Class{__includes = Entity}

function ExitDoor:init(object)
	Entity.init(self)
	self.type = 'exit door'
	local position = Vector(object.x - object.width * 0.5, object.y - object.height * 0.5)
	local shape_arguments = {0, 0, object.width, object.height}
	local sprite = self:addComponent(Sprite{
		image='res/img/door.png',
		frames=5,
		duration=1.0,
		loop=false,
		position=position,
		shape_arguments=shape_arguments,
	})
	local collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments=shape_arguments,
		body_type='static',
		enter=Func(ExitDoor.contact, self),
		sensor=true,
		position=position
	})
	
end

function ExitDoor:contact(other)
end

return ExitDoor