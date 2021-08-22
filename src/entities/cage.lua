local Cage = Class{__includes = Entity}

function Cage:init(object)
	Entity.init(self)
	self.type = 'cage'
	local color = object.properties.color
	local position = Vector(object.x - object.width * 0.5, object.y - object.height * 0.5)
	local shape_arguments = {0, 0, object.width, object.height}
	self.sprite = self:addComponent(Sprite{
		image='res/img/cage.png',
		frames=1,
		duration=1.0,
		loop=false,
		position=position,
		shape_arguments=shape_arguments,
	})
	self.collider = self:addComponent(Collider{
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