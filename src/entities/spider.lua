local Enemy = require('src.enemy.enemy')
local EnemyBrain = require('src.enemy.enemy_brain')
local Sprite = require('src.components.sprite')

local Spider = Class{__includes = Enemy}

local DEFAULT_WRAP_DURATION = 20

function Spider:init(object)
	Enemy.init(self, object, {color = {0.15, 0.15, 0.15, 1}})
	self.type = 'spider'
	self.wrapDuration = (object.properties and object.properties.wrapDuration) or DEFAULT_WRAP_DURATION

	local shape_arguments = {0, 0, object.width, object.height}
	self.sprite = self:addComponent(Sprite{
		image = 'res/img/enemy_spider.png',
		frames = 1,
		duration = 1.0,
		loop = false,
		shape_arguments = shape_arguments,
	})
end

function Spider:draw()
	Entity.draw(self)
end

function Spider:update(dt)
	Enemy.update(self, dt)

	if self:isStunned() then
		return
	end

	self:wrapOverlappingTarget()
end

-- wraps the first valid (alive, unwrapped, not already banned by this
-- spider) overlapping player, then bans and immediately retargets
-- (DECISIONS Q2/Q3)
function Spider:wrapOverlappingTarget()
	local bounds = self.collider:getBounds()
	local colls = world:queryBounds(bounds)

	for _, c in ipairs(colls) do
		local entity = c.entity
		if entity and entity.type == 'player' and not entity.wrapped and not entity:isDead()
			and not EnemyBrain.isBanned(self.bans, entity) then
			entity:wrap(self.wrapDuration)
			self:ban(entity, self.banDuration)
			return
		end
	end
end

return Spider
