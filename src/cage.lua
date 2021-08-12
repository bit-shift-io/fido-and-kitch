local Cage = Class{__includes = Entity}

function Cage:init(object)
	Entity.init(self)
	local color = object.properties.color
	local sprite = self:addComponent(Sprite{
		image='res/img/cage.png',
		scale=Vector(0.1, 0.1), 
		frames=1, 
		duration=1.0, 
		loop=false
	})
	local collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments={0, 0, 30, 30}, 
		body_type='static',
		postSolve=Cage.contact, 
		sprite=sprite, 
		position=Vector(object.x, object.y)
	})
	
end

function Cage:contact(other)
	print('Cage has made contact with something!')
end

return Cage