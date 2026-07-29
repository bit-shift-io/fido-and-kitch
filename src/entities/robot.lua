local Enemy = require('src.enemy.enemy')
local EnemyBrain = require('src.enemy.enemy_brain')

local Robot = Class{__includes = Enemy}

local DEFAULT_SHOVE_SPEED = 40
local DEFAULT_CHASE_BAN_TIME = 10

function Robot:init(object)
	Enemy.init(self, object, {color = {0.55, 0.55, 0.6, 1}})
	self.type = 'robot'
	self.shoveSpeed = (object.properties and object.properties.shoveSpeed) or DEFAULT_SHOVE_SPEED
	self.chaseBanTime = (object.properties and object.properties.chaseBanTime) or DEFAULT_CHASE_BAN_TIME
	self.chaseTimer = {target = nil, elapsed = 0}
end

function Robot:update(dt)
	Enemy.update(self, dt)

	if self:isStunned() then
		return
	end

	self:updateChaseBan(dt)
	self:shoveOverlappingPlayers(dt)
end

-- after ~chaseBanTime seconds pursuing the same target, ban them so the
-- robot rotates its attention (DECISIONS Q3)
function Robot:updateChaseBan(dt)
	local target = self:findTarget()
	local nextTimer, shouldBan = EnemyBrain.updateChaseTimer(self.chaseTimer, target, dt, self.chaseBanTime)
	self.chaseTimer = nextTimer

	if shouldBan then
		self:ban(target, self.banDuration)
	end
end

-- GOTCHA: WalkIdleState/PlayerMovement rewrite the player's horizontal
-- velocity from input every frame, so a velocity impulse gets silently
-- eaten -- shoving as a direct per-frame position offset survives that
-- reset regardless of update order (see HANDOFF.md)
function Robot:shoveOverlappingPlayers(dt)
	local bounds = self.collider:getBounds()
	local colls = world:queryBounds(bounds)

	for _, c in ipairs(colls) do
		local entity = c.entity
		if entity and entity.type == 'player' then
			local offsetX = EnemyBrain.decideShove(self.collider:getX(), entity.collider:getX(), self.shoveSpeed, entity.wrapped)
			if offsetX ~= 0 then
				entity.collider:setX(entity.collider:getX() + offsetX * dt)
			end
		end
	end
end

return Robot
