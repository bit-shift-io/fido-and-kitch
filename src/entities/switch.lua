local Switch = Class{__includes = Entity}

function Switch:init(object)
	Entity.init(self)
	self.name = object.name
	self.type = 'switch'
	local position = Vector(object.x+16, object.y-16)
	self.sprite = self:addComponent(Sprite{
		image='res/img/switch.png',
		scale=Vector(0.2, 0.2),
		frames=3,
		position=position,
		offset=Vector(70,80),
		duration=1.0,
		loop=false
	})
	self.collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments={0, 0, 32, 32}, 
		body_type='static',
		position=Vector(object.x+16, object.y-16),
		sensor=true,
	})
	self:addComponent(Usable{
		entity=self,
		use=Func(self.use, self)
	})

	self.target = map:getObjectById(object.properties.target.id)
end

function Switch:use(user)
	print('switch has been used')

	-- TODO: really we need a play and play({reverse=true}) method
	-- added to the sprite
	local frameNum = self.sprite.frameNum
	if frameNum == 1 then
		frameNum = 3
	else
		frameNum = 1
	end
	self.sprite:setFrameNum(frameNum)

	if self.target then
		-- todo: do something to the target
		print('do something to target')
	end
end

return Switch