local Cage = Class{__includes = Entity}

function Cage:init(object)
	Entity.init(self)
	self.name = 'cage'
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
		enter=Func(Cage.contact),
		sensor=true,
		sprite=sprite, 
		position=Vector(object.x, object.y)
	})
	
	self:addComponent(Usable{
		entity=self,
		use=Func(self.use, self),
		requiredItem=string.format('key_%s', color)
	})
end

function Cage:contact(other)
end

function Cage:use(user)
	print('Cage has been used')
end

return Cage