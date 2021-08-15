local Teleport = Class{__includes = Entity}

function Teleport:init(object)
	Entity.init(self)
	self.name = 'teleport'
	local id = object.id
	local target = object.properties.target
	local position = Vector(object.x+16, object.y-16)
	local sprite = self:addComponent(Sprite{
		image='res/img/teleporter_1.png',
		scale=Vector(0.03, 0.03), 
		frames=1, 
		duration=1.0,
		offset=Vector(500,500),
		loop=false
	})
	local collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments={0, 0, 32, 32}, 
		body_type='static',
		enter=Func(Teleport.contact, self),
		sensor=true,
		sprite=sprite, 
		position=position
	})
end

function Teleport:contact(other)

end

return Teleport