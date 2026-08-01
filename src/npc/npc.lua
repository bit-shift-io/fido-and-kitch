-- Shared base for roaming NPCs (robot, spider): player-like physics
-- (gravity, solid vs. world, sensor vs. players), sprite animations
-- (idle/walk driven by FSM), and the brain-driven chase FSM.
local NPCBrain = require('src.npc.npc_brain')
local NPCStates = require('src.npc.npc_states')
local PushableSupport = require('src.components.pushable.pushable_support')
local PlayerSensors = require('src.player.player_sensors')
local DeathFlash = require('src.components.death_flash')
local Sprite = require('src.components.sprite')
local StateMachine = require('src.components.state_machine')

local NPC = Class{__includes = Entity}

local DEFAULT_SPEED = 70
local DEFAULT_BAN_DURATION = 30
local DEFAULT_WANDER_RANGE = 60
local DEFAULT_STUN_DURATION = 10
local ALIGN_THRESHOLD = 4
local STOMP_ZONE_RATIO = 0.5

function NPC:init(object, props)
	Entity.init(self, object)
	props = props or {}

	self.speed = (object.properties and object.properties.speed) or DEFAULT_SPEED
	self.banDuration = (object.properties and object.properties.banDuration) or DEFAULT_BAN_DURATION
	self.wanderRange = (object.properties and object.properties.wanderRange) or DEFAULT_WANDER_RANGE
	self.stunDuration = (object.properties and object.properties.stunDuration) or DEFAULT_STUN_DURATION
	self.alignThreshold = ALIGN_THRESHOLD
	self.color = props.color or {1, 1, 1, 1}
	self.bans = {}
	self.wanderDirection = 1
	self.stunTimer = 0

	local position = Rect.centreOfMapObject(object)
	local shape_arguments = Rect.shapeArgs(object.width, object.height)
	self.homeX = position.x
	self.homeY = position.y
	self.homeFacing = 'right'
	self.visible = true
	self.alpha = 1

	local idle_image = props.idleImage or 'res/img/enemy_spider.png'
	local walk_image = props.walkImage or idle_image

	local animations = {
		idle = Sprite{
			image = idle_image,
			frames = 1,
			duration = 1.0,
			loop = false,
			shape_arguments = shape_arguments,
		},
		walk = Sprite{
			image = walk_image,
			frames = 1,
			duration = 1.0,
			loop = false,
			shape_arguments = shape_arguments,
		},
	}

	self.animations = self:addComponent(StateMachine{
		states = animations,
		entity = self,
		currentState = 'idle',
	})

	self.collider = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = shape_arguments,
		body_type = 'dynamic',
		position = position,
		fixedRotation = true,
		sprite = self.animations,
	})
	self.collider:setGroupIndex(PushableSupport.nextGroupIndex())
	self.collider.nonSolidEntityTypes = {player = true}

	self.fsm = self:addComponent(StateMachine{
		stateClasses = NPCStates,
		entity = self,
		currentState = 'ChaseState',
	})
end

function NPC:queryPlayers()
	local players = {}
	for _, collider in pairs(world.colliders) do
		local entity = collider.entity
		if entity and entity.type == 'player' then
			table.insert(players, entity)
		end
	end
	return players
end

function NPC:queryLadder()
	local bounds = self.collider:getBounds()
	bounds.left = bounds.left + 4
	bounds.right = bounds.right - 4
	bounds.bottom = bounds.bottom - 4

	local colls = world:queryBounds(bounds)
	for _, c in ipairs(colls) do
		local entity = c.entity
		if entity and entity.isLadder then
			return entity
		end
	end
	return nil
end

function NPC:queryLadderBelow()
	local bounds = self.collider:getBounds()
	bounds.left = bounds.left + 4
	bounds.right = bounds.right - 4
	bounds.top = bounds.bottom + 4
	bounds.bottom = bounds.bottom + 5

	local colls = world:queryBounds(bounds)
	for _, c in ipairs(colls) do
		local entity = c.entity
		if entity and entity.isLadder then
			return entity
		end
	end
	return nil
end

function NPC:findTarget()
	local enemyPos = {x = self.collider:getX(), y = self.collider:getY()}

	local candidates = {}
	for _, player in ipairs(self:queryPlayers()) do
		table.insert(candidates, {
			x = player.collider:getX(),
			y = player.collider:getY(),
			isDead = utils.bindSelf(player.isDead, player),
			wrapped = player.wrapped,
			entity = player,
		})
	end

	local target = NPCBrain.pickTarget(enemyPos, candidates, self.bans)
	return target and target.entity
end

function NPC:ban(player, duration)
	NPCBrain.ban(self.bans, player, duration or self.banDuration)
end

function NPC:isStunned()
	return self.fsm.currentState == self.fsm.states.StunnedState
end

function NPC:stun(duration)
	self.stunTimer = duration or self.stunDuration
	if not self:isStunned() then
		self.fsm:setState('StunnedState')
	end
end

function NPC:checkForStomp()
	local bounds = self.collider:getBounds()
	local colls = world:queryBounds(bounds)

	for _, c in ipairs(colls) do
		local entity = c.entity
		if entity and entity.type == 'player' and not entity:isDead() then
			local _, playerVelocityY = entity.collider:getLinearVelocity()
			local playerBounds = entity.collider:getBounds()
			if NPCBrain.isStomp(playerVelocityY, playerBounds.bottom, bounds.top, bounds.height, STOMP_ZONE_RATIO) then
				self:stun()
				return
			end
		end
	end
end

function NPC:draw()
	if not self.visible then
		return
	end

	-- headless (unit tier): no love.graphics to set color on, but component
	-- draw() calls are themselves headless-safe no-ops -- see Sprite's
	-- isHeadless -- so still forward to them.
	if love and love.graphics then
		love.graphics.setColor(1, 1, 1, self.alpha)
	end

	Entity.draw(self)

	if love and love.graphics then
		love.graphics.setColor(1, 1, 1, 1)
	end
end

function NPC:isDead()
	return self.fsm.currentState == self.fsm.states.DeadState
end

function NPC:die(deathType)
	if self:isDead() then
		return
	end

	self.deathType = deathType
	self.fsm:setState('DeadState')
end

function NPC:respawn()
	self.collider:setPosition(self.homeX, self.homeY)
	self.stunTimer = 0
	self.bans = {}

	if self.animations.currentState.setFacing then
		self.animations.currentState:setFacing(self.homeFacing)
	end

	self.fsm:setState('WanderState')
	self:onRespawn()
	DeathFlash.startSpawn(self)
end

-- No-op hooks for subclasses that need to react to their own death/respawn
-- (e.g. Spider releasing a wrapped player on death, Robot clearing its
-- chase-ban timer on respawn) without the shared DeadState/NPC:respawn
-- knowing about any enemy-specific state.
function NPC:onDeath()
end

function NPC:onRespawn()
end

function NPC:update(dt)
	Entity.update(self, dt)

	if self.fadeTween then
		local finished = self.fadeTween:update(dt)
		if finished then
			self.fadeTween = nil
		end
	end

	if self:isDead() then
		return
	end

	local killZone = PlayerSensors.queryKillZone(world, self.collider)
	if killZone then
		killZone.sound:play(killZone.deathType)
		self:die(killZone.deathType)
		return
	end

	NPCBrain.tickBans(self.bans, dt)
	self:checkForStomp()
end

return NPC