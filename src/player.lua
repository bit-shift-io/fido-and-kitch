local PlayerStates = require('player_states')

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

	--[[
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
				fsm.options.player.collider:setGravityScale(0)
			end,
			onleaveladder = function(fsm, name, from, to)
				print('ladder exit ') 
				fsm.options.player.collider:setType('dynamic')
				fsm.options.player.collider:setGravityScale(1)
			end
		}
	})
	]]--

	self.fsm = self:addComponent(StateMachine{
		stateClasses=PlayerStates,
		entity=self,
		currentState='WalkIdleState'
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