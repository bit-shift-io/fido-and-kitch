local TeleportTrail = require("src.fx.teleport_trail")

local TeleportTravelState = Class({})

function TeleportTravelState:enter(prevState, params)
	local player = self.entity
	self.curve = params.curve
	self.duration = params.duration
	self.destX = params.destX
	self.destY = params.destY
	self.sourceTeleport = params.sourceTeleport
	self.targetTeleport = params.targetTeleport
	self.elapsed = 0

	player.visible = false

	player.collider:setType("kinematic")
	player.collider:setGravityScale(0)
	player.collider:setLinearVelocity(0, 0)
	player.collider:setSensor(true)

	player:setAnimation("idle")

	if player.speedStreak then
		player.speedStreak:disable()
	end
end

function TeleportTravelState:update(dt)
	local player = self.entity
	self.elapsed = self.elapsed + dt

	local t = math.min(self.elapsed / self.duration, 1)
	local pos = TeleportTrail.computeCurvePoint(self.curve, t)
	player.collider:setPosition(pos.x, pos.y)

	if self.elapsed >= self.duration then
		player.collider:setPosition(self.destX, self.destY)
		player.fsm:setState("WalkIdleState")
	end
end

function TeleportTravelState:exit()
	local player = self.entity

	if self.targetTeleport and self.targetTeleport.map and self.targetTeleport.map.fx then
		local TeleportBurst = require("src.fx.teleport_burst")
		self.targetTeleport.map.fx:add(TeleportBurst({
			position = { x = self.destX, y = self.destY },
		}))
	end

	player.visible = true

	player.collider:setType("dynamic")
	player.collider:setGravityScale(1)
	player.collider:setLinearVelocity(0, 0)
	player.collider:setSensor(false)
end

return TeleportTravelState
