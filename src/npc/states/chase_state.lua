-- src/npc/states/chase_state.lua
local Class = require("lib.hump.class")
local Vector = require("lib.hump.vector")
local NpcLocomotion = require("src.npc.npc_locomotion")

local ChaseState = Class({})

function ChaseState:enter(prevState)
	local entity = self.entity
	if entity.target then
		local tx, ty = entity:getTargetPos()
		entity.chaseTarget = { x = tx, y = ty }
	end
end

function ChaseState:update(dt)
	dt = NpcLocomotion.sanitizeDt(dt, "ChaseState")
	local entity = self.entity

	if not entity.target or not entity.chaseTarget then
		return
	end

	-- Update chase target to current target position
	local tx, ty = entity:getTargetPos()
	entity.chaseTarget.x = tx
	entity.chaseTarget.y = ty

	local dx = entity.chaseTarget.x - entity.x
	local dy = entity.chaseTarget.y - entity.y
	local dist = math.sqrt(dx * dx + dy * dy)

	if dist < 5 then
		return
	end

	local dir = Vector(dx, dy):normalized()
	NpcLocomotion.stepHorizontal(entity, dir.x, dt, 300, 80)
end

function ChaseState:exit(prevState)
	local entity = self.entity
	entity.chaseTarget = nil
end

return ChaseState
