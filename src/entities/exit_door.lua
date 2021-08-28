local ExitDoor = Class{__includes = Entity}

function ExitDoor:init(object)
	Entity.init(self)
	self.type = 'exit_door'
	self.name = object.name
	local position = Vector(object.x + object.width * 0.5, object.y - object.height * 0.5)
	local shape_arguments = {0, 0, object.width, object.height}
	self.sprite = self:addComponent(Sprite{
		image='res/img/door.png',
		frames=5,
		duration=1.0,
		loop=false,
		position=position,
		shape_arguments=shape_arguments,
	})
	local collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments=shape_arguments,
		body_type='static',
		enter=utils.forwardFunc(ExitDoor.contact, self),
		sensor=true,
		position=position
	})
	
end

function ExitDoor:contact(other)
end

function ExitDoor:actorReached(actor)
	print('some birdy reached the exit!')

	self.sprite.timeline:setFinishFunc(function()
		print("door is open!")
		actor:queueDestroy()

		self.sprite.timeline:setFinishFunc(function()
			print("door is closed!")
			self.sprite.timeline:setFinishFunc(nil)
		end)
		self.sprite.timeline:reverse()
		self.sprite.timeline:play()
	end)
	self.sprite.timeline:reset()
	self.sprite.timeline:play()
end

function ExitDoor:open()
	print('all objectives achived, open door for player to exit')
	self.sprite.timeline:play()
end

return ExitDoor