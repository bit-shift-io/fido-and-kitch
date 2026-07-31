local NPC = require('src.npc.npc')
local NPCBrain = require('src.npc.npc_brain')

local Spider = Class{__includes = NPC}

local DEFAULT_WRAP_DURATION = 20

function Spider:init(object)
	NPC.init(self, object, {
		color = {0.15, 0.15, 0.15, 1},
		idleImage = 'res/img/enemy_spider.png',
	})
	self.type = 'spider'
	self.wrapDuration = (object.properties and object.properties.wrapDuration) or DEFAULT_WRAP_DURATION
end

function Spider:draw()
	Entity.draw(self)
end

function Spider:update(dt)
	NPC.update(self, dt)

	if self:isStunned() then
		return
	end

	self:wrapOverlappingTarget()
end

function Spider:wrapOverlappingTarget()
	local bounds = self.collider:getBounds()
	local colls = world:queryBounds(bounds)

	for _, c in ipairs(colls) do
		local entity = c.entity
		if entity and entity.type == 'player' and not entity.wrapped and not entity:isDead()
			and not NPCBrain.isBanned(self.bans, entity) then
			entity:wrap(self.wrapDuration)
			self:ban(entity, self.banDuration)
			return
		end
	end
end

return Spider