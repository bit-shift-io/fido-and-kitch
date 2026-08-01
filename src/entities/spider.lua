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
	NPC.draw(self)
end

function Spider:update(dt)
	NPC.update(self, dt)

	if self.wrappedTarget and not self.wrappedTarget.wrapped then
		self.wrappedTarget = nil
	end

	if self:isDead() or self:isStunned() then
		return
	end

	self:wrapOverlappingTarget()
end

function Spider:wrapOverlappingTarget()
	if self.wrappedTarget then
		return
	end

	local bounds = self.collider:getBounds()
	local colls = world:queryBounds(bounds)

	for _, c in ipairs(colls) do
		local entity = c.entity
		if entity and entity.type == 'player' and not entity.wrapped and not entity:isDead()
			and not NPCBrain.isBanned(self.bans, entity) then
			entity:wrap(self.wrapDuration)
			self.wrappedTarget = entity
			self:ban(entity, self.banDuration)
			return
		end
	end
end

-- A kill zone (or anything else) can kill the Spider while it still has a
-- player wrapped -- release them the instant death starts rather than
-- leaving them stuck on a corpse's wrap timer until the Spider respawns.
function Spider:onDeath()
	if self.wrappedTarget and self.wrappedTarget.wrapped then
		self.wrappedTarget:releaseWrap()
	end
	self.wrappedTarget = nil
end

return Spider