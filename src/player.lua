local Player = Class{__includes = Entity}

function Player:init(object)
	Entity.init(self)
	self.name = 'player'
	self.type = 'player'
	self.ladder = null
	local character = 'dog';
	local position = Vector(object.x + 14, object.y - 14)

	self.sprite = self:addComponent(Sprite{
		frames=string.format('res/img/%s/Idle (${i}).png', character),
		frameCount=10, 
		duration=1.0,
		scale=Vector(0.1, 0.1),
		position=position,
		offset=Vector(280, 320),
		playing=true
	})
	self.object = object
	self.speed = 100;

	self.collider = self:addComponent(Collider{
		shape_type='rectangle', 
		shape_arguments={0, 0, 20, 28}, 
		postSolve=Func(self.contact, self),
		sprite=self.sprite,
		position=position,
		entity=self,
		fixedRotation=true
	})

	self.inventory = self:addComponent(Inventory{})

	-- https://github.com/kyleconroy/lua-state-machine
	self.fsm = StateMachine.create({
		player = self,
		initial = 'idle',
		events = {
		  { name = 'doIdle',  from = {'ladder', 'fall', 'walk'},  to = 'idle' },
		  { name = 'doFall', from = {'idle', 'walk'}, to = 'fall'  },
		  { name = 'doWalk',  from = {'idle', 'fall'},    to = 'walk' },
		  { name = 'doLadder',  from = {'idle', 'walk'},    to = 'ladder' },
	  	},
		callbacks = {
			onidle = function(fsm, event, from, to, msg) 
				print('idle! ')    
			end,
			onfall = function(fsm, event, from, to, msg) 
				print('fall! ')    
			end,
			onwalk = function(fsm, event, from, to, msg) 
				print('walk! ')    
			end,
			onenterladder = function(fsm, name, from, to)
				print('ladder enter ') 
				fsm.options.player.collider:setType('kinematic')
			end,
			onleaveladder = function(fsm, name, from, to)
				print('ladder exit ') 
				fsm.options.player.collider:setType('dynamic')
			end
		}
	})

	-- other states: use, teleport

	print('qwe')
end


function Player:contact(other)
	--print('player has made contact with something!')
end


function Player:checkForUsables()
	local x = self.collider:getX()
	local y = self.collider:getY()
	local colls = world:queryRectangleArea(x-1,y-1,x+1,y+1)
	for _, c in ipairs(colls) do
		local entity = c.entity
		if entity then 
			local usable = entity:getComponentByType(Usable)
			if usable ~= nil then
				print('found entity with usable', c.entity.name)
				if usable:canUse(self) then
					usable:use(self)
				end
			end
		end
	end
end


function Player:update(dt)
	Entity.update(self, dt)
	local x = self.collider:getX()
	local y = self.collider:getY()
	local delta = self.speed * dt

	local eDownLast = self.eDown
	self.eDown = love.keyboard.isDown("e")
	if self.eDown == true and eDownLast == false then
		self:checkForUsables()
	end

	-- is user falling
	local isFalling = false
	local v_x, v_y = self.collider:getLinearVelocity()
	if (v_y > 2) then
		isFalling = true
		self.fsm:doFall()
	else
		if (self.fsm.current == 'fall') then
			self.fsm:doIdle()
		end
	end

	-- reset horizontal velocity
	self.collider:setLinearVelocity(0, v_y)

	if isFalling then
		return
	end

	-- movement
	-- https://github.com/jlett/Platformer-Tutorial

	local isWalking = false
	
	if love.keyboard.isDown("right") then
		self.collider:setLinearVelocity(100, v_y)
		isWalking = true
	end

	if love.keyboard.isDown("left") then
		self.collider:setLinearVelocity(-100, v_y)
		isWalking = true
	end

	local isUsingLadder = false

	-- TODO: when the player is using the ladder, we somehow need to disable
	-- collisions with tiles, we did this in the dart version by putting the player into 
	-- 'kinematic' mode. OR we can disable the collision that a ladder tile
	-- might be on, so player can move through it.... this second method won't work
	-- if there are other physics objects on top of the ladder!
	if (love.keyboard.isDown("up") and self.ladder ~= nil) then
		self.collider:setLinearVelocity(0, -100)
		isUsingLadder = true
	end

	if (love.keyboard.isDown("down")) then
		local ladderBelow = self:ladderBelow()
		if self.ladder ~= nil or ladderBelow ~= nil then
			self.collider:setLinearVelocity(0, 100)
			isUsingLadder = true
		end
	end

	if (isUsingLadder) then
		self.fsm:doLadder()
	else
		if (self.fsm.current == 'ladder' and self.ladder == nil) then
			self.fsm:doIdle()
		end
	end

	if (self.fsm.current ~= 'ladder') then
		if (isWalking) then
			self.fsm:doWalk()
		else
			self.fsm:doIdle()
		end
	end
end

function Player:ladderBelow()
	local bounds = self.collider:getBounds()
	local x = self.collider:getX()
	local cy = self.collider:getY()
	local y = bounds.bottom + 10

	local colls = world:queryRectangleArea(x-10,y-10,x+10,y+10)
	for _, c in ipairs(colls) do
		local entity = c.entity
		if entity then 
			if entity.isLadder then -- should we have a ladder component?
				return entity
			end
		end
	end

	return nil
end


function Player:pickup(pickup)
	local entity = pickup.entity
	print('player picked up a ' .. pickup.itemName)
	self.inventory:addItems(pickup.itemName, pickup.itemCount)
	entity:queueDestroy()
end


return Player