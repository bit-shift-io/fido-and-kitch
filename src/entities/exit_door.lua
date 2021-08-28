local ExitDoor = Class{__includes = Entity}

function ExitDoor:init(object)
	Entity.init(self)
	self.type = 'exit_door'
	self.name = object.name
	self.state = 'closed'
	self.desiredState = 'closed'
	local position = Vector(object.x + object.width * 0.5, object.y - object.height * 0.5)
	local shape_arguments = {0, 0, object.width, object.height}
	self.sprite = self:addComponent(Sprite{
		image='res/img/door.png',
		frames=5,
		duration=1.0,
		loop=false,
		position=position,
		shape_arguments=shape_arguments,
		finish=utils.forwardFunc(ExitDoor.animFinished, self)
	})
	local collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments=shape_arguments,
		body_type='static',
		enter=utils.forwardFunc(ExitDoor.contact, self),
		sensor=true,
		position=position
	})
	self.usable = self:addComponent(Usable{
		entity=self,
		use=utils.func(ExitDoor.use, self),
		enabled=false
	})

	self.entitysWaiting = {}
	self.enableUsableOnOpen = false
end

function ExitDoor:contact(other)
end

-- let the given actor through and then destroy the actor
function ExitDoor:actorReached(actor)
	print('some birdy reached the exit!')
	self:addWaitingEntity(actor)
	self:updateState('openThenClose')
end

-- open the door for players to exit
-- once opened it cannot be closed
function ExitDoor:open()
	print('all objectives achived, open door for player to exit')
	self.enableUsableOnOpen = true
	self.desiredState = 'open'
	self:updateState('open')
end


function ExitDoor:use(user)
	self:addWaitingEntity(user)
	self:updateState()
end

function ExitDoor:addWaitingEntity(entity)
	if (self.state == 'open') then
		entity:queueDestroy()
		self:checkEndGame()
		return
	end

	table.insert(self.entitysWaiting, entity)
end

function ExitDoor:updateState(desiredState)
	-- once open for the player to exit, keep it forced open
	if (self.enableUsableOnOpen) then
		desiredState = 'open'
	end

	if (self.state == 'closed' and (desiredState == 'open' or desiredState == 'openThenClose')) then
		self.desiredState = desiredState
		self.state = 'opening'
		self.sprite.timeline:reset()
		self.sprite.timeline:play()
		return
	end

	if (self.state == 'open' and desiredState == 'closed') then
		self.desiredState = desiredState
		self.state = 'closing'
		self.sprite.timeline:reverse()
		self.sprite.timeline:play()
		return
	end
end

function ExitDoor:animFinished()
	if (self.state == 'opening') then
		self.state = 'open'
		for _, e in ipairs(self.entitysWaiting) do
			e:queueDestroy()
		end
		self.entitysWaiting = {}
		self:checkEndGame()
		if (self.enableUsableOnOpen) then
			self.usable.enabled = true
		end
	elseif (self.state == 'closing') then
		self.state = 'closed'
	end

	if (self.desiredState ~= self.state) then
		self:updateState(self.desiredState)
	end
end

function ExitDoor:checkEndGame()
	-- TODO: if all players have left the map, game over man!
end

return ExitDoor