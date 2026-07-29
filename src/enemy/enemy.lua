-- Shared base for roaming enemies (robot, spider): player-like physics
-- (gravity, solid vs. world, sensor vs. players), placeholder-quad
-- rendering, and the brain-driven chase FSM. See .scratch/enemies/.
local EnemyBrain = require('src.enemy.enemy_brain')
local EnemyStates = require('src.enemy.enemy_states')
local PushableSupport = require('src.components.pushable.pushable_support')

local Enemy = Class{__includes = Entity}

local DEFAULT_SPEED = 70
local DEFAULT_BAN_DURATION = 30
local DEFAULT_WANDER_RANGE = 60
local DEFAULT_STUN_DURATION = 10
local ALIGN_THRESHOLD = 4
local STOMP_ZONE_RATIO = 0.5

function Enemy:init(object, props)
	Entity.init(self)
	props = props or {}

	self.object = object
	self.name = object.name
	self.speed = (object.properties and object.properties.speed) or DEFAULT_SPEED
	self.banDuration = (object.properties and object.properties.banDuration) or DEFAULT_BAN_DURATION
	self.wanderRange = (object.properties and object.properties.wanderRange) or DEFAULT_WANDER_RANGE
	self.stunDuration = (object.properties and object.properties.stunDuration) or DEFAULT_STUN_DURATION
	self.alignThreshold = ALIGN_THRESHOLD
	self.color = props.color or {1, 1, 1, 1}
	self.bans = {}
	self.wanderDirection = 1
	self.stunTimer = 0

	local width = object.width
	local height = object.height
	local position = Vector(object.x + width * 0.5, object.y - height * 0.5)
	local shape_arguments = {0, 0, width, height}
	self.homeX = position.x

	self.collider = self:addComponent(Collider{
		shape_type = 'rectangle',
		shape_arguments = shape_arguments,
		body_type = 'dynamic',
		position = position,
		fixedRotation = true,
	})
	-- solid vs. world/pushables, sensor vs. players (DECISIONS Q13); a
	-- concrete groupIndex avoids the nil==nil terrain-passthrough gotcha
	-- (see PushableSupport.nextGroupIndex)
	self.collider:setGroupIndex(PushableSupport.nextGroupIndex())
	self.collider.nonSolidEntityTypes = {player = true}

	self.fsm = self:addComponent(StateMachine{
		stateClasses = EnemyStates,
		entity = self,
		currentState = 'ChaseState',
	})
end

-- every player entity currently in the world, regardless of distance
function Enemy:queryPlayers()
	local players = {}
	for _, collider in pairs(world.colliders) do
		local entity = collider.entity
		if entity and entity.type == 'player' then
			table.insert(players, entity)
		end
	end
	return players
end

-- ladder the enemy is currently overlapping (climbs up toward it), mirroring
-- Player:queryLadder
function Enemy:queryLadder()
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

-- ladder starting just below the enemy's feet (climbs down onto it),
-- mirroring Player:queryLadderBelow
function Enemy:queryLadderBelow()
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

-- nearest alive player, or nil if none are valid targets
function Enemy:findTarget()
	local enemyPos = {x = self.collider:getX(), y = self.collider:getY()}

	local candidates = {}
	for _, player in ipairs(self:queryPlayers()) do
		table.insert(candidates, {
			x = player.collider:getX(),
			y = player.collider:getY(),
			isDead = utils.func(player.isDead, player),
			wrapped = player.wrapped,
			entity = player,
		})
	end

	local target = EnemyBrain.pickTarget(enemyPos, candidates, self.bans)
	return target and target.entity
end

-- harassment ban (DECISIONS Q3): excludes `player` from targeting by this
-- enemy instance until `duration` (default banDuration) elapses
function Enemy:ban(player, duration)
	EnemyBrain.ban(self.bans, player, duration or self.banDuration)
end

function Enemy:isStunned()
	return self.fsm.currentState == self.fsm.states.StunnedState
end

-- head stomp (DECISIONS Q10): freezes the enemy for `duration` (default
-- stunDuration) without a harassment ban. Goes through the FSM directly
-- rather than tryTransition so a re-stomp on an already-stunned enemy still
-- refreshes the timer (StateMachine:setState no-ops on an unchanged state)
function Enemy:stun(duration)
	self.stunTimer = duration or self.stunDuration
	if not self:isStunned() then
		self.fsm:setState('StunnedState')
	end
end

-- falling player, overlapping, feet in the enemy's upper region -> stomp
-- (DECISIONS Q10); bounces the player and stuns this enemy, no ban
function Enemy:checkForStomp()
	local bounds = self.collider:getBounds()
	local colls = world:queryBounds(bounds)

	for _, c in ipairs(colls) do
		local entity = c.entity
		if entity and entity.type == 'player' and not entity:isDead() then
			local _, playerVelocityY = entity.collider:getLinearVelocity()
			local playerBounds = entity.collider:getBounds()
			if EnemyBrain.isStomp(playerVelocityY, playerBounds.bottom, bounds.top, bounds.height, STOMP_ZONE_RATIO) then
				self:stun()
				entity:bounce()
				return
			end
		end
	end
end

function Enemy:update(dt)
	Entity.update(self, dt)
	EnemyBrain.tickBans(self.bans, dt)
	self:checkForStomp()
end

function Enemy:draw()
	local r, g, b, a = love.graphics.getColor()
	local c = self.color
	if self:isStunned() then
		-- flatten toward white as a simple "stunned" tint on the placeholder quad
		love.graphics.setColor((c[1] + 1) * 0.5, (c[2] + 1) * 0.5, (c[3] + 1) * 0.5, c[4])
	else
		love.graphics.setColor(c)
	end
	local bounds = self.collider:getBounds()
	love.graphics.rectangle('fill', bounds.left, bounds.top, bounds.width, bounds.height)
	love.graphics.setColor(r, g, b, a)
end

return Enemy
