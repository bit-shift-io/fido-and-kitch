local Switch = Class{__includes = Entity}

function Switch:init(object)
	Entity.init(self)
	self.name = object.name
	self.type = 'switch'
	local position = Vector(object.x - object.width * 0.5, object.y - object.height * 0.5)
	local shape_arguments = {0, 0, object.width, object.height}
	self.sprite = self:addComponent(Sprite{
		image='res/img/switch.png',
		frames=3,
		position=position,
		shape_arguments=shape_arguments,
		duration=1.0,
		loop=false
	})
	self.collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments=shape_arguments,
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