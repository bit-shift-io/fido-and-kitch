local WrappedState = Class({})

function WrappedState:enter()
	local player = self.entity
	player.wrapped = true
	player:setAnimation("idle")
end

function WrappedState:exit()
	local player = self.entity
	player.wrapped = false
	player.web = nil
end

function WrappedState:update(dt)
	local player = self.entity

	local _, v_y = player.collider:getLinearVelocity()
	player.collider:setLinearVelocity(0, v_y)

	player.web:update(dt)
	if player.web:isExpired() then
		player.fsm:setState("WalkIdleState")
	end
end

return WrappedState
