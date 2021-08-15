local Switch = Class{__includes = Entity}

function Switch:init(object)
	Entity.init(self)
	self.name = 'switch'
	self.sprite = self:addComponent(Sprite{
		image='res/img/switch.png',
		scale=Vector(0.3, 0.3),
		frames=2,
		duration=1.0,
		loop=false,
		playing=false
	})
	self.collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments={0, 0, 30, 30}, 
		body_type='static',
		enter=Func(Switch.contact, self),
		sprite=sprite,
		position=Vector(object.x, object.y),
		sensor=true,
	})

	self:addComponent(Usable{
		entity=self,
		use=Func(self.use, self)
	})
end

function Switch:contact(other)
end

function Switch:use(user)
	print('switch has been used')
	local frameNum = self.sprite.frameNum
	if frameNum == 1 then
		frameNum = 2
	else
		frameNum = 1
	end
	self.sprite:setFrameNum(frameNum)
end

return Switch