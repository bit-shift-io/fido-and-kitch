local Switch = Class{__includes = Entity}

function Switch:init(object)
	Entity.init(self)
	self.name = 'switch'
	self.object = obbject

	local position = Vector(object.x, object.y)
	self.sprite = self:addComponent(Sprite{
		image='res/img/switch.png',
		scale=Vector(0.3, 0.3),
		frames=3,
		position=position,
		duration=1.0,
		loop=false
	})
	self.collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments={0, 0, 30, 30}, 
		body_type='static',
		position=position,
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