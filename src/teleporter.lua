local Teleporter = Class{__includes = Entity}

function Teleporter:init(object)
	Entity.init(self)
	local id = object.id
	local target = object.properties.target
	local sprite = self:addComponent(Sprite{
		image='res/img/teleporter_1.png',
		scale=Vector(0.04, 0.04), 
		frames=1, 
		duration=1.0, 
		loop=false
	})
	local collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments={0, 0, 30, 30}, 
		body_type='static',
		postSolve=Teleporter.contact, 
		sprite=sprite, 
		position=Vector(object.x, object.y)
	})
end

function Teleporter:contact(other)
	print('Teleporter has made contact with something!')
end

return Teleporter