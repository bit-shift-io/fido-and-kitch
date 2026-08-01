local NPC = require('src.npc.npc')
local NPCBrain = require('src.npc.npc_brain')

local Robot = Class{__includes = NPC}

local DEFAULT_SHOVE_SPEED = 40
local DEFAULT_CHASE_BAN_TIME = 10

function Robot:init(object)
	NPC.init(self, object, {
		color = {0.55, 0.55, 0.6, 1},
		idleImage = 'res/img/enemy_blob.png',
	})
	self.type = 'robot'
	self.shoveSpeed = (object.properties and object.properties.shoveSpeed) or DEFAULT_SHOVE_SPEED
	self.chaseBanTime = (object.properties and object.properties.chaseBanTime) or DEFAULT_CHASE_BAN_TIME
	self.chaseTimer = {target = nil, elapsed = 0}
end

function Robot:draw()
	NPC.draw(self)
end

function Robot:update(dt)
	NPC.update(self, dt)

	if self:isDead() or self:isStunned() then
		return
	end

	self:updateChaseBan(dt)
	self:shoveOverlappingPlayers(dt)
end

function Robot:onRespawn()
	self.chaseTimer = {target = nil, elapsed = 0}
end

function Robot:updateChaseBan(dt)
	local target = self:findTarget()
	local nextTimer, shouldBan = NPCBrain.updateChaseTimer(self.chaseTimer, target, dt, self.chaseBanTime)
	self.chaseTimer = nextTimer

	if shouldBan then
		self:ban(target, self.banDuration)
	end
end

function Robot:shoveOverlappingPlayers(dt)
	local bounds = self.collider:getBounds()
	local colls = world:queryBounds(bounds)

	for _, c in ipairs(colls) do
		local entity = c.entity
		if entity and entity.type == 'player' then
			local offsetX = NPCBrain.decideShove(self.collider:getX(), entity.collider:getX(), self.shoveSpeed, entity.wrapped)
			if offsetX ~= 0 then
				entity.collider:setX(entity.collider:getX() + offsetX * dt)
			end
		end
	end
end

return Robot