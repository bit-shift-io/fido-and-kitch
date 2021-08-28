local PlayerStates = require('player_states')

local Player = Class{__includes = Entity}

function Player:init(props)
	Entity.init(self)

	local object = props.object
	self.index = props.index
	self.name = 'player'
	self.type = 'player'
	self.ladder = nil
	local character = self.index == 1 and 'dog' or 'cat';
	local height = 50
	local width = 50
	local position = Vector(object.x + width * 0.5, object.y - height * 0.5)
	local offset = Vector(0,8)
	local shape_arguments = {0, 0, width, height}
	local physics_arguments = {0, 0, 20, 30}

	-- use the statemachine as the animation state system
	local animations = {
		idle=Sprite{
			frames=string.format('res/img/%s/Idle (${i}).png', character),
			frameCount=10,
			duration=1.0,
			position=position,
			playing=true,
			shape_arguments=shape_arguments,
			offset=offset,
		},
		fall=Sprite{
			frames=string.format('res/img/%s/Fall (${i}).png', character),
			frameCount=8, 
			duration=1.0,
			position=position,
			playing=true,
			shape_arguments=shape_arguments,
			offset=offset,
		},
		walk=Sprite{
			frames=string.format('res/img/%s/Walk (${i}).png', character),
			frameCount=10, 
			duration=1.0,
			position=position,
			playing=true,
			shape_arguments=shape_arguments,
			offset=offset,
		},
		climb=Sprite{
			frames=string.format('res/img/%s/Jump (${i}).png', character),
			frameCount=8,
			duration=1.0,
			position=position,
			playing=true,
			shape_arguments=shape_arguments,
			offset=offset,
		}
	}

	self.animations = self:addComponent(StateMachine{
		states=animations,
		entity=self,
		currentState='idle'
	})

	self.object = object
	self.speed = 100;
	self.climbSpeed = 100;

	self.collider = self:addComponent(Collider{
		shape_type='rectangle',
		shape_arguments=physics_arguments,
		postSolve=utils.forwardFunc(self.contact, self),
		sprite=self.animations,
		position=position,
		entity=self,
		fixedRotation=true
	})
	-- items in the -ve group do not collide with each other, this stops player colliding
	self.collider:setGroupIndex(-1)

	self.inventory = self:addComponent(Inventory{})

	self.fsm = self:addComponent(StateMachine{
		stateClasses=PlayerStates,
		entity=self,
		currentState='WalkIdleState'
	})
end

function Player:setAnimation(name)
	self.animations:setState(name)
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

function Player:queryLadder()
	local bounds = self.collider:getBounds()

	-- make it narrower
	bounds.left = bounds.left + 10
	bounds.right = bounds.right - 10

	bounds.bottom = bounds.bottom - 4 -- why is this number so high?
	local colls = world:queryBounds(bounds)
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

function Player:queryLadderBelow()
	local bounds = self.collider:getBounds()

	-- make it narrower
	bounds.left = bounds.left + 10
	bounds.right = bounds.right - 10

	bounds.top = bounds.bottom + 4 -- why is this number so high?
	bounds.bottom = bounds.bottom + 5
	local colls = world:queryBounds(bounds)
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

function Player:queryOnGround()
	local bounds = self.collider:getBounds()

	bounds.top = bounds.bottom + 4 -- why is this number so high?
	bounds.bottom = bounds.bottom + 5
	local colls = world:queryBounds(bounds)
	for _, c in ipairs(colls) do
		local entity = c.entity
		if entity == nil then 
			return true
		end
	end
	return false
end

function Player:pickup(pickup)
	local entity = pickup.entity
	print('player picked up a ' .. pickup.itemName)
	self.inventory:addItems(pickup.itemName, pickup.itemCount)
	entity:queueDestroy()
end

function Player:isDown(action)
	local actionMap = {}

	local joysticks = love.joystick.getJoysticks()
	local joystick = joysticks[self.index]

	if (self.index == 1) then
		actionMap = {
			left='left',
			right='right',
			up='up',
			down='down',
			use='rshift'
		}
	end

	if (self.index == 2) then
		actionMap = {
			left='a',
			right='d',
			up='w',
			down='s',
			use='e'
		}
	end

	if (joystick) then
		local deadzone = 0.2
		local hor, vert = joystick:getAxes()

		if (action == 'left') then
			return hor < -deadzone
		end

		if (action == 'right') then
			return hor > deadzone
		end

		if (action == 'up') then
			return vert < -deadzone
		end

		if (action == 'down') then
			return vert > deadzone
		end

		if (action == 'use') then
			return joystick:isDown(1)
		end
	end

	local key = actionMap[action]
	return love.keyboard.isDown(key)
end


return Player