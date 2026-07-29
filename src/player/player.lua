local PlayerStates = require('src.player.player_states')
local SafePosition = require('src.player.safe_position')
local Flash = require('src.components.flash')
local GroundSupport = require('src.player.ground_support')
local Web = require('src.enemy.web')

local Player = Class{__includes = Entity}

-- spawn/respawn flash: non-blocking, accompanied by a fade-in from transparent
local SPAWN_FLASH_INTERVAL = 0.15
local SPAWN_FLASH_BLINKS = 8
local SPAWN_FADE_DURATION = SPAWN_FLASH_INTERVAL * SPAWN_FLASH_BLINKS

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
			loop=true,
			position=position,
			playing=true,
			shape_arguments=shape_arguments,
			offset=offset,
		},
		fall=Sprite{
			frames=string.format('res/img/%s/Fall (${i}).png', character),
			frameCount=8, 
			duration=1.0,
			loop=true,
			position=position,
			playing=true,
			shape_arguments=shape_arguments,
			offset=offset,
		},
		walk=Sprite{
			frames=string.format('res/img/%s/Run (${i}).png', character),
			frameCount=8, 
			duration=0.65,
			loop=true,
			position=position,
			playing=true,
			shape_arguments=shape_arguments,
			offset=offset,
		},
		climb=Sprite{
			frames=string.format('res/img/%s/Jump (${i}).png', character),
			frameCount=8,
			duration=1.0,
			loop=true,
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
	self.facing = 'right'

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

	-- no assets yet at res/snd/entity_player_{jump,land,step,death}.wav;
	-- Sound:play warns and skips until they're added
	self.sound = self:addComponent(Sound{
		sounds = {
			jump = 'res/snd/entity_player_jump.wav',
			land = 'res/snd/entity_player_land.wav',
			step = 'res/snd/entity_player_step.wav',
			death = 'res/snd/entity_player_death.wav',
			mount = 'res/snd/entity_ladder_climb.wav',
		}
	})
	self.stepTimer = 0

	self.fsm = self:addComponent(StateMachine{
		stateClasses=PlayerStates,
		entity=self,
		currentState='WalkIdleState'
	})

	self.safePosition = SafePosition.new(position.x, position.y)

	self.visible = true
	self.alpha = 1
	self.deathSignal = Signal{}
end

function Player:setAnimation(name)
	self.animations:setState(name)
end

function Player:setFacing(facing)
	if self.facing == facing then
		return
	end

	self.facing = facing
	for _, animation in pairs(self.animations.states) do
		if animation.setFacing then
			animation:setFacing(facing)
		end
	end
end

function Player:contact(other)
	print('player has made contact with something!')
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

	if self.fadeTween then
		local finished = self.fadeTween:update(dt)
		if finished then
			self.fadeTween = nil
		end
	end

	if not self:isDead() then
		local killZone = self:queryKillZone()
		if killZone then
			killZone.sound:play(killZone.deathType)
			self:die(killZone.deathType)
		end
	end

	local grounded = self.fsm.currentState == self.fsm.states.WalkIdleState and self:queryFullySupported()
	self.safePosition:update(dt, grounded, self.collider:getX(), self.collider:getY())
end

function Player:draw()
	if self.visible then
		love.graphics.setColor(1, 1, 1, self.alpha)
		Entity.draw(self)
		love.graphics.setColor(1, 1, 1, 1)

		if self.web then
			self.web:draw(self.collider:getBounds())
		end
	end

	if conf.drawphysics then
		self:drawSafePositionMarker()
	end
end

function Player:isDead()
	return self.fsm.currentState == self.fsm.states.DeadState
end

-- head-stomp counterplay bounce (DECISIONS Q10): a jump-like upward impulse.
-- Falling into FallState is already the natural next transition, same as a
-- normal jump, so no explicit state change is needed here.
local DEFAULT_BOUNCE_FORCE = 220

function Player:bounce(force)
	local v_x, v_y = self.collider:getLinearVelocity()
	self.collider:setLinearVelocity(v_x, -(force or DEFAULT_BOUNCE_FORCE))
end

-- kills the player: locks movement, flashes, then signals InGameState to
-- resolve the death (respawn or game over) once the flash completes
function Player:die(deathType)
	if self:isDead() then
		return
	end

	self.deathType = deathType
	self.fsm:setState('DeadState')
end

-- invoked when the death flash finishes; hands the decision to whoever is
-- listening (InGameState owns the shared lives pool)
function Player:resolveDeath()
	self.deathSignal:emit(self, self.deathType)
end

-- caught by a spider's web (DECISIONS Q8); ignored if already wrapped or dead
function Player:wrap(duration)
	if self.wrapped or self:isDead() then
		return
	end

	self.web = Web{duration = duration}
	self.fsm:setState('WrappedState')
end

function Player:respawn()
	self.collider:setPosition(self.safePosition.x, self.safePosition.y)
	self.fsm:setState('WalkIdleState')
	self:startSpawnFlash()
end

-- non-blocking flash: purely visual, movement/input stay live throughout.
-- Used after a respawn and on the player's initial spawn at map load.
-- Paired with a fade-in from transparent, over the same duration.
function Player:startSpawnFlash()
	self.alpha = 0
	self.fadeTween = Tween.new(SPAWN_FADE_DURATION, self, {alpha = 1})

	self.flash = self:addComponent(Flash{
		target = self,
		property = 'visible',
		interval = SPAWN_FLASH_INTERVAL,
		blinks = SPAWN_FLASH_BLINKS,
	})
end

-- temporary debug draw of the tracked safe position; strip once issue 04/05 land
function Player:drawSafePositionMarker()
	local size = 6
	love.graphics.setColor(0, 1, 0, 1)
	love.graphics.line(self.safePosition.x - size, self.safePosition.y, self.safePosition.x + size, self.safePosition.y)
	love.graphics.line(self.safePosition.x, self.safePosition.y - size, self.safePosition.x, self.safePosition.y + size)
	love.graphics.setColor(1, 1, 1, 1)
end

function Player:queryKillZone()
	local bounds = self.collider:getBounds()

	-- make it narrower
	bounds.left = bounds.left + 4
	bounds.right = bounds.right - 4

	local colls = world:queryBounds(bounds)
	for _, c in ipairs(colls) do
		local entity = c.entity
		if entity then
			if entity.isKillZone then
				return entity
			end
		end
	end
	return nil
end

function Player:queryLadder()
	local bounds = self.collider:getBounds()

	-- make it narrower
	bounds.left = bounds.left + 4
	bounds.right = bounds.right - 4

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
	bounds.left = bounds.left + 4
	bounds.right = bounds.right - 4

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

	bounds.top = bounds.bottom + 4 
	bounds.bottom = bounds.bottom + 5
	local colls = world:queryBounds(bounds)
	for _, c in ipairs(colls) do
		local entity = c.entity
		-- `walkable` is a capability flag ("this collider counts as ground
		-- when solid"), not a standing guarantee -- an entity-owned collider
		-- like a drawbridge deck can currently be a sensor (e.g. closed), in
		-- which case it must not count as ground
		if entity == nil or (c.walkable and not c.other.sensor) then
			return true
		end
	end
	return false
end

-- stricter than queryOnGround(): requires support under both feet corners,
-- so safe-position tracking never records a spot hanging off a ledge edge
function Player:queryFullySupported()
	return GroundSupport.isFullySupported(world, self.collider:getBounds())
end

function Player:pickup(pickup)
	local entity = pickup.entity
	print('player picked up a ' .. pickup.itemName)
	local sound = entity:getComponentByType(Sound)
	if sound ~= nil then
		sound:play('pickup')
	end
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
			use='q'
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