-- Path follow component
-- follow a polyline

local World = require("src.physics.bump.world")

local PathFollow = Class({})

function PathFollow:init(props)
	self.type = "path_follow"
	self.path = props.path
	self.sprite = props.sprite
	self.collider = props.collider
	self.offset = props.offset or Vector(0, 0)
	self.ignoreCollider = props.ignoreCollider

	self._blocked = false
	self._checkedFirstSample = false
	self._lastGoodPos = self.path:getPositionV(0) + self.offset

	if self.collider then
		self.previousGravityScale = self.collider.gravityScale
		self.previousVelocityX, self.previousVelocityY = self.collider:getLinearVelocity()
		self.collider:setGravityScale(0)
		self.collider:setLinearVelocity(0, 0)
	end

	local speed = props.speed
	local duration = self.path.length / speed
	local finish = props.finish
	self.timeline = Timeline({
		duration = duration,
		easing = props.easing,
		finish = function()
			self:finish()
			if finish then
				finish()
			end
		end,
	})

	self._lastPos = nil
	self._velocity = Vector(0, 0)

	if self.sprite then
		local pos = self.path:getPositionV(0)
		self.sprite:setPositionV(pos)
		self._lastPos = pos
	end
end

function PathFollow:update(dt)
	if self.timeline.playing == false then
		return
	end
	self.timeline:update(dt)

	local distance = self.timeline:timePercent() * self.path.length
	local pos = self.path:getPositionV(distance)
	pos = pos + self.offset

	if self.collider and self._checkedFirstSample and self:_isBlocked(pos) then
		self._blocked = true
		self.timeline:stop()
		pos = self._lastGoodPos
	else
		self._checkedFirstSample = true
		self._lastGoodPos = pos
	end

	if self.sprite then
		self.sprite:setPositionV(pos)
	end

	if self.collider then
		self.collider:setPositionV(pos)
	end

	if self._lastPos then
		self._velocity = (pos - self._lastPos) / dt
	end
	self._lastPos = pos
end

-- Would the player's collider overlap a solid, non-ignored collider at
-- `pos` if it were dynamic right now? Simulated via a lightweight stand-in
-- passed to World.colFilter rather than flipping the real collider's
-- bodyType, since a kinematic body always crosses via the 'a.bodyType ==
-- kinematic' rule in World.colFilter -- see src/physics/bump/world.lua.
function PathFollow:_isBlocked(pos)
	local halfWidth = self.collider.width / 2
	local halfHeight = self.collider.height / 2
	local bounds = {
		left = pos.x - halfWidth,
		right = pos.x + halfWidth,
		top = pos.y - halfHeight,
		bottom = pos.y + halfHeight,
	}

	local asDynamic = {
		bodyType = "dynamic",
		sensor = self.collider.sensor,
		groupIndex = self.collider.groupIndex,
		colFilterFn = self.collider.colFilterFn,
		nonSolidEntityTypes = self.collider.nonSolidEntityTypes,
		entity = self.collider.entity,
	}

	for _, other in ipairs(world:queryOverlap(bounds)) do
		if other ~= self.collider and other ~= self.ignoreCollider then
			if World.colFilter(asDynamic, other) == "slide" then
				return true
			end
		end
	end

	return false
end

function PathFollow:wasBlocked()
	return self._blocked
end

function PathFollow:getPositionV()
	local distance = self.timeline:timePercent() * self.path.length
	local pos = self.path:getPositionV(distance)
	return pos
end

function PathFollow:getVelocity()
	if self.finished then
		return Vector(0, 0)
	end
	return self._velocity:clone()
end

function PathFollow:finish()
	if self.finished then
		return
	end

	self.finished = true
	if self.collider then
		self.collider:setGravityScale(self.previousGravityScale or 1)
	end
end

function PathFollow:destroy()
	self:finish()
end

function PathFollow:draw()
	self.path:draw()
end

return PathFollow
