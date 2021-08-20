local Cage = Class{__includes = Entity}

function Cage:init(object)
	Entity.init(self)
	self.type = 'cage'
	local color = object.properties.color
	local position = Vector(object.x+16, object.y-16)
	local sprite = self:addComponent(Sprite{
		image='res/img/cage.png',
		scale=Vector(0.1, 0.1), 
		frames=1, 
		duration=1.0, 
		loop=false,
		position=position,
		offset=Vector(280, 320),
	})
	local collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments={0, 0, 32, 32}, 
		body_type='static',
		sensor=true,
		position=position
	})
	
	self:addComponent(Usable{
		entity=self,
		use=Func(self.use, self),
		requiredItem=string.format('key_%s', color)
	})
end

function Cage:use(user)
	print('Cage has been used')
end

return Cage