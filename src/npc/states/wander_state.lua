-- src/npc/states/wander_state.lua
local Class = require("lib.hump.class")
local Vector = require("lib.hump.vector")
local NpcLocomotion = require("src.npc.npc_locomotion")

local WanderState = Class({})

function WanderState:enter(prevState)
	local entity = self.entity
	-- Pick random point within wander radius
	local radius = entity.config.wanderRadius or 100
	local angle = math.random() * 2 * math.pi
	entity.wanderTarget = {
		x = entity.x + math.cos(angle) * radius,
		y = entity.y + math.sin(angle) * radius,
	}
	entity.wanderTimer = 0
end

function WanderState:update(dt)
	dt = NpcLocomotion.sanitizeDt(dt, "WanderState")
	local entity = self.entity
	if not entity.wanderTarget then
		self:enter()
		return
	end

	local dx = entity.wanderTarget.x - entity.x
	local dy = entity.wanderTarget.y - entity.y
	local dist = math.sqrt(dx * dx + dy * dy)

	if dist < 10 then
		-- Reached target, pick new one
		entity.wanderTimer = entity.wanderTimer + dt
		if entity.wanderTimer > 2 then
			self:enter()
		end
		return
	end

	-- Move toward target (horizontal only — gravity handles vertical)
	local dir = Vector(dx, dy):normalized()
	NpcLocomotion.stepHorizontal(entity, dir.x, dt, 200, 50)
end

function WanderState:exit(prevState)
	local entity = self.entity
	entity.wanderTarget = nil
	entity.wanderTimer = 0
end

return WanderState
