local JumpPad = Class{__includes = Entity}

function JumpPad:init(object)
	Entity.init(self)
	self.type = 'jump_pad'
	self.name = object.name
	local position = Vector(object.x + object.width * 0.5, object.y - object.height * 0.5)
	local shape_arguments = {0, 0, object.width, object.height}
	self.sprite = self:addComponent(Sprite{
		image='res/img/spring/Spring - 1.png',
		frames=1,
		duration=1.0,
		loop=true,
		playing=true,
		shape_arguments=shape_arguments
	})
	
	self.collider = self:addComponent(Collider{
		shape_type='rectangle',
		shape_arguments=shape_arguments,
		body_type='static',
		sprite=self.sprite,
		position=position,
		sensor=true,
		entity=self
	})

    self.pathFollow = self:addComponent(PathFollow{
		sprite=self.sprite,
        path=Path(object),
        finish=Func(self.finish, self),
    })
end

return JumpPad