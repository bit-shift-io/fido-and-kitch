-- src/npc/states/idle_state.lua
local Class = require("lib.hump.class")

local IdleState = Class({})

function IdleState:enter(prevState)
	local entity = self.entity
	entity.collider:setLinearVelocity(0, 0)
end

function IdleState:update(entity, dt) end

function IdleState:exit(prevState) end

return IdleState
